// PhotoStyle+Kernel.swift (layer-styles PY-1 stubs, PY-5 bodies): the workspace
// as SuiteImaging's LayerStyleTarget, so the suite's style panel and the style.*
// commands style Photo's layers with no Photo style type. The style is the
// primary layer's; an adjustment layer takes none. The panel's state is real
// from PY-1; `setStyle` throws notBuilt until PY-5. Linux-safe.
import SuiteImaging
import SuiteKernel

extension PhotoWorkspace: LayerStyleTarget {
    /// Why an adjustment layer's style commands are off.
    static let styleOnAdjustment = "Layer styles go on pixel and text layers."
    /// The task that fills `setStyle`.
    static let styleNotBuilt = CatalogError.notBuilt(id: "style", feature: "photo layer-styles PY-5")

    public var styleSelection: LayerStyle? {
        guard let layer = selectedLayer else { return nil }
        if case .adjustment = layer.kind { return nil }
        return layer.style
    }

    public var styleHelp: String? {
        guard let layer = selectedLayer else { return StyleRules.noLayerHelp }
        if case .adjustment = layer.kind { return Self.styleOnAdjustment }
        return nil
    }

    public mutating func showStylePanel(_ kind: StyleKind?) { stylePanel = kind }

    public mutating func setStyle(_ style: LayerStyle, name: String, drag: String?) throws {
        throw Self.styleNotBuilt
    }
}
