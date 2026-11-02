// PhotoStyle+Kernel.swift (layer-styles PY-1 stubs, PY-5 bodies): the workspace
// as SuiteImaging's LayerStyleTarget, so the suite's style panel and the style.*
// commands style Photo's layers with no Photo style type. A style goes on every
// picked pixel and text layer; an adjustment layer takes none. The style shown
// is the primary layer's, or the first picked image layer's when the primary is
// an adjustment layer. Linux-safe.
import SuiteImaging
import SuiteKernel

extension PhotoWorkspace: LayerStyleTarget {
    /// Why the style commands are off when only adjustment layers are picked.
    static let styleOnAdjustment = "Layer styles go on pixel and text layers."

    public var styleSelection: LayerStyle? {
        guard let layer = selectedLayer else { return nil }
        guard case .adjustment = layer.kind else { return layer.style }
        return movableSelectedLayers.first.map { layers[$0].style }
    }

    public var styleHelp: String? {
        guard selectedLayer != nil else { return StyleRules.noLayerHelp }
        return movableSelectedLayers.isEmpty ? Self.styleOnAdjustment : nil
    }

    public mutating func showStylePanel(_ kind: StyleKind?) { stylePanel = kind }

    /// Sets `style`, clamped, on every picked image layer (the picked layers an
    /// adjustment layer can't stand in for, as Move uses them) as one layer-list
    /// step named `name`, no tiles; steps under one `drag` token fold. With no
    /// image layer picked it refuses with `styleHelp` and records nothing.
    public mutating func setStyle(_ style: LayerStyle, name: String, drag: String?) throws {
        let targets = movableSelectedLayers
        guard !targets.isEmpty else {
            throw CatalogError.unavailable(id: "style", why: styleHelp ?? StyleRules.noLayerHelp)
        }
        let clamped = StyleRules.clamped(style)
        guard targets.contains(where: { layers[$0].style != clamped }) else { return }
        let key = drag.map { "style-" + targets.map { layers[$0].id }.joined(separator: ",") + "-" + $0 }
        recordLayers(named: name, coalescing: key)
        for at in targets { layers[at].style = clamped }
        touch(.all)
    }
}
