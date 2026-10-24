// LayerStyleRules.swift (layer-styles LS-1 stubs returning the input, LS-5 bodies): ranges, defaults, one effect
// per kind, paint order, reach, presets and the JSON `style.copy` returns and `style.paste` takes. Linux-safe.
import SuiteKernel

public enum StyleRules {
    /// The why-not every style command shows when nothing stylable is selected.
    public static let noLayerHelp = "Select a layer to style."
    /// What a `style.*` run throws until LS-6 fills the bodies.
    public static let notBuilt = CatalogError.notBuilt(id: "style", feature: "layer-styles LS-6")

    /// Under the layer, then over it. Stub: the panel's order until LS-5.
    public static let paintOrder: [StyleKind] = StyleKind.allCases

    /// `kind`'s defaults, turned on. Stub: zero parameters of the matching case until LS-5.
    public static func defaults(_ kind: StyleKind) -> StyleEffect {
        let parameters: StyleParameters
        switch kind {
        case .dropShadow, .innerShadow: parameters = .shadow(StyleShadow(color: .black, angle: 0, distance: 0, spread: 0, size: 0))
        case .outerGlow, .innerGlow: parameters = .glow(StyleGlow(color: .white, spread: 0, size: 0))
        case .stroke: parameters = .stroke(StyleStroke(fill: .solid(.black), size: 1, position: .outside))
        case .colorOverlay, .gradientOverlay: parameters = .overlay(StyleOverlay(fill: .solid(.black)))
        case .bevel:
            parameters = .bevel(StyleBevel(shape: .innerBevel, technique: .smooth, depth: 1, up: true, size: 0, soften: 0,
                                           angle: 0, altitude: 0, highlight: .white, highlightBlend: .screen, highlightOpacity: 1,
                                           shadow: .black, shadowBlend: .multiply, shadowOpacity: 1))
        }
        return StyleEffect(kind: kind, isEnabled: true, blendMode: .normal, opacity: 1, parameters: parameters)
    }

    /// Every parameter in its range (packet Pseudocode). Stub: the input until LS-5.
    public static func clamped(_ style: LayerStyle) -> LayerStyle { style }

    /// Why a decoded style is malformed, nil when fine. Stub: nil until LS-5.
    public static func check(_ style: LayerStyle) -> String? { nil }

    /// `style` with `kind`'s defaults on, replacing any effect of that kind. Stub: the input until LS-5.
    public static func adding(_ kind: StyleKind, to style: LayerStyle) -> LayerStyle { style }

    /// `style` with `patch` (`blend`, `opacity` and parameter fields) applied to `kind`'s effect;
    /// throws on a non-finite value. Stub: the input until LS-5.
    public static func setting(_ patch: JSONValue, on kind: StyleKind, in style: LayerStyle) throws -> LayerStyle { style }

    /// The px a renderer pads on each side. Stub: 0 until LS-5.
    public static func reach(_ style: LayerStyle) -> Int { 0 }

    /// Soft Shadow, Lifted, Outline, Neon, Embossed. Stub: none until LS-5.
    public static let presets: [StylePreset] = []

    /// The style as JSON. Stub: an empty object until LS-5.
    public static func json(_ style: LayerStyle) -> JSONValue { .object([:]) }

    /// The style `json` holds, the first effect of each kind kept. Stub: throws until LS-5.
    public static func style(json: JSONValue) throws -> LayerStyle { throw ImagingError.notBuilt("layer-styles LS-5") }
}

/// A named built-in style.
public struct StylePreset: Hashable, Sendable {
    public var name: String; public var style: LayerStyle
    public init(name: String, style: LayerStyle) { (self.name, self.style) = (name, style) }
}
