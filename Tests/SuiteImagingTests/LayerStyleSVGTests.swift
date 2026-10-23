// LayerStyleSVGTests.swift (layer-styles LS-1 written disabled, LS-7 turns it on and adds the
// substitution, region and gradient cases): one `<filter>` per styled shape from W3C Filter Effects primitives.
import CoreRaster
import Foundation
import Testing
import SuiteImaging
import SuiteKernel

@Suite struct LayerStyleSVGTests {
    static let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
    /// 135° and 8 px with y down: blur σ = size / 3 = 4, offset (5.66, 5.66), down and to the right.
    @Test func shadowGoesDown() {
        let (svg, warnings) = LayerStyleSVG.filter(shadowStyle(), id: "s1", box: Self.box)
        #expect(svg.hasPrefix("<filter id=\"s1\"") && warnings.isEmpty && svg.contains("stdDeviation=\"4\""))
        #expect(svg.contains("dx=\"5.66\"") && svg.contains("dy=\"5.66\"") && svg.contains("mode=\"multiply\""))
        #expect(svg.hasSuffix("</filter>"))
        // Straight down at 90°, straight left at 0° (the light's angle; the shadow falls away from it).
        #expect(LayerStyleSVG.filter(shadowStyle(angle: 90), id: "s1", box: Self.box).svg.contains("dx=\"0\" dy=\"8\""))
        #expect(LayerStyleSVG.filter(shadowStyle(angle: 0), id: "s1", box: Self.box).svg.contains("dx=\"-8\" dy=\"0\""))
    }

    /// A switched-off effect writes no primitive; a style with nothing on writes no filter at all.
    @Test func disabledWritesNothing() {
        var style = shadowStyle()
        style.effects[0].isEnabled = false
        #expect(LayerStyleSVG.filter(style, id: "s1", box: Self.box) == ("", []))
        style.effects.append(StyleRules.defaults(.colorOverlay))
        let (svg, warnings) = LayerStyleSVG.filter(style, id: "s1", box: Self.box)
        #expect(svg.contains("flood-color=\"#ff0000\"") && warnings.isEmpty)
        #expect(!svg.contains("feGaussianBlur") && !svg.contains("feOffset") && !svg.contains("multiply"))
    }

    /// A mode outside SVG 1.1's five writes its Filter Effects keyword and exactly one warning naming it.
    @Test func substitutionWarns() {
        var style = shadowStyle()
        style.effects[0].blendMode = .colorDodge
        let (svg, warnings) = LayerStyleSVG.filter(style, id: "s1", box: Self.box)
        #expect(svg.contains("mode=\"color-dodge\"") && warnings.count == 1)
        #expect(warnings.first?.contains("color dodge") == true && warnings.first?.contains("drop shadow") == true)
        style.effects[0].blendMode = .screen
        #expect(LayerStyleSVG.filter(style, id: "s1", box: Self.box).warnings.isEmpty)
    }

    /// The region is the box grown by `StyleRules.reach` on every side, so nothing is clipped.
    @Test func regionGrowsByReach() {
        let style = shadowStyle()
        #expect(StyleRules.reach(style) == 20)
        let svg = LayerStyleSVG.filter(style, id: "s1", box: Rect(minX: 10, minY: 30, maxX: 60, maxY: 50)).svg
        #expect(svg.contains(#"filterUnits="userSpaceOnUse" x="-10" y="10" width="90" height="60""#))
    }

    /// A gradient overlay paints an image of the box filled by `GradientSVG.definition`, clipped to the shape.
    @Test func gradientOverlayWritesItsPoints() {
        let ramp = GradientRules.rotated(GradientRules.converted(.solid(.black), to: .linear, in: Self.box), to: 90, in: Self.box)
        var overlay = StyleRules.defaults(.gradientOverlay)
        overlay.parameters = .overlay(StyleOverlay(fill: ramp))
        let (svg, warnings) = LayerStyleSVG.filter(LayerStyle(effects: [overlay], fillOpacity: 1), id: "s1", box: Self.box)
        let definition = GradientSVG.definition(ramp, id: "s1-gradient")
        #expect(!definition.isEmpty && warnings.isEmpty && svg.contains("<feImage"))
        #expect(svg.contains(escaped(definition)) && svg.contains("operator=\"in\""))
    }

    /// An outside stroke dilates the alpha under the layer and warns that its corners are square.
    @Test func strokeWarnsSquareCorners() {
        let (svg, warnings) = LayerStyleSVG.filter(strokeStyle(.outside, size: 3), id: "s1", box: Self.box)
        #expect(svg.contains(#"operator="dilate" radius="3""#) && warnings == ["The stroke's corners are square in SVG."])
    }

    /// Fill opacity scales the layer's own alpha and leaves the effects alone.
    @Test func fillOpacityScalesTheLayer() {
        var style = shadowStyle()
        style.fillOpacity = 0.5
        let svg = LayerStyleSVG.filter(style, id: "s1", box: Self.box).svg
        #expect(svg.contains(#"<feComponentTransfer in="SourceGraphic""#) && svg.contains(#"slope="0.5""#))
    }

    /// The markup an `feImage` data URI carries inside a quoted attribute.
    func escaped(_ markup: String) -> String {
        markup.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: "#", with: "%23")
    }
}
