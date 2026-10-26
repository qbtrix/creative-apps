// HaloStyle+Kernel.swift: Halo's project as SuiteImaging's LayerStyleTarget (layer-styles HY-1 stubs, HY-5
// bodies), so the eleven `style.*` commands run on the selected layer. The style lives in `HaloLayer.style`
// (SuiteImaging's LayerStyle, never a Halo copy); a drop shadow's distance, size and opacity and an outer glow's
// size and opacity are HaloProperty tracks, sampled at the playhead and keyed there when a track exists.
// Linux-safe.
import SuiteImaging
import SuiteKernel

extension HaloProject: LayerStyleTarget {
    /// Why nothing can be styled: no composition is open.
    static let noStyleComposition = "Make or open a composition to style a layer."

    /// Why the style commands can't run: no composition; nil otherwise (no layer is the kernel's own help).
    public var styleHelp: String? { selectedComposition == nil ? Self.noStyleComposition : nil }

    /// The selected layer's style, `.none` for an unstyled layer; nil with no layer selected.
    public var styleSelection: LayerStyle? {
        guard styleHelp == nil, let layer = selectedLayer else { return nil }
        return layer.style ?? LayerStyle.none
    }

    /// Opens the panel at `kind`'s section, or closes it; not an undo step.
    public mutating func showStylePanel(_ kind: StyleKind?) { stylePanel = kind }

    /// Stub until HY-5: refuses, changing nothing.
    public mutating func setStyle(_ style: LayerStyle, name: String, drag: String?) throws {
        throw CatalogError.notBuilt(id: "style", feature: "layer-styles HY-5")
    }
}

extension HaloLayer {
    /// A style property's value with no track: the style's own value when it has that effect, else 0.
    /// Stub until HY-5 reads it from the style.
    func styleValue(_ property: HaloProperty) -> Double { 0 }
}
