// LayerStyleGalleryTests.swift (layer-styles LS-2): the gallery declares the `layer-style` page SJ0 opens, the page
// starts on no style, the panel names the eight styles in the packet's order, and a switch that can't act yet says
// why. macOS only.
import SuiteImaging
@testable import SuiteUI
import Testing

@MainActor @Suite struct LayerStyleGalleryTests {
    @Test func theGalleryDeclaresTheLayerStylePage() {
        #expect(GalleryLayerStyle.name == "layer-style")
        #expect(SuiteGallery.pageNames.contains("layer-style"))
        #expect(SuiteGallery.resolve("layer-style") == .page("layer-style"))
        #expect(SuiteGallery.areas.filter { $0["layer-style"] != nil }.count == 1)
    }

    @Test func thePageStartsOnNoStyleWithEveryStyleOff() {
        #expect(GalleryLayerStyle.start == LayerStyle.none)
        #expect(StyleKind.allCases.allSatisfy { GalleryLayerStyle.start.effect($0) == nil })
        #expect(GalleryLayerStyle.summary(.none) == "no style")
        var shadow = StyleRules.defaults(.dropShadow)
        #expect(GalleryLayerStyle.summary(LayerStyle(effects: [shadow], fillOpacity: 1)) == "dropShadow")
        shadow.isEnabled = false
        #expect(GalleryLayerStyle.summary(LayerStyle(effects: [shadow], fillOpacity: 1)) == "no style")
    }

    @Test func thePanelNamesTheEightStylesInOrder() {
        #expect(StyleKind.allCases.map(LayerStyleText.title) == [
            "Drop Shadow", "Inner Shadow", "Outer Glow", "Inner Glow", "Stroke", "Color Overlay", "Gradient Overlay",
            "Bevel & Emboss",
        ])
        #expect(LayerStyleText.toggleID(.dropShadow) == "suite.style.toggle.dropShadow")
    }

    @Test func aSwitchThatCantActYetSaysWhy() {
        // A typed value: a bare `LayerStyle.none` passed as `LayerStyle?` reads as Optional's `.none` (no layer).
        let unstyled: LayerStyle? = LayerStyle(effects: [], fillOpacity: 1)
        #expect(LayerStyleText.reason(style: nil, help: nil) == StyleRules.noLayerHelp)
        #expect(LayerStyleText.reason(style: unstyled, help: "This layer is locked.") == "This layer is locked.")
        #expect(LayerStyleText.reason(style: unstyled, help: nil) == LayerStyleText.pending)
        #expect(!LayerStyleText.pending.isEmpty)
    }

    @Test func aLogLineIsTheCommandThenTheIntent() {
        #expect(GalleryLayerStyle.line(.show(.stroke)).hasPrefix("style.panel "))
        #expect(GalleryLayerStyle.line(.preset("Lifted")).hasPrefix("style.preset "))
    }
}
