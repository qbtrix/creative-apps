// HaloLayerPicks+Kernel.swift: the LAYERS list's multi-select, an adapter
// onto SuiteKernel's `Selection` (the one pick rule). A pick toggles a layer
// in or out, extends from the anchor through the list's order, or replaces
// the picks; the selected layer is always the last pick, so every
// single-layer command still reads `selectedLayerID`. Any other way the
// selected layer changes (a plain select, a new or deleted layer) drops the
// other picks: `pickedLayerIDs` trusts the picks only while their primary is
// the selected layer. Delete Layer removes every pick (HaloLayerEdits).
// Not an undo step. Linux-safe.
import SuiteKernel

extension HaloProject {
    /// The picked layers of the selected composition: the picks while the selected layer is their primary,
    /// else the selected layer alone.
    public var pickedLayerIDs: Set<String> {
        let layers = Set(selectedComposition?.layers.map(\.id) ?? [])
        guard let selected = selectedLayerID, layers.contains(selected) else { return [] }
        guard layerSelection.primary == selected else { return [selected] }
        return layerSelection.set.intersection(layers)
    }

    /// One click on layer `id` in the LAYERS list: `pick` toggles it, extends to it from the anchor in list
    /// order, or makes it the only pick. An unknown id changes nothing; the last pick becomes the selected layer.
    public mutating func pickLayer(_ id: String, _ pick: Pick) {
        let order = selectedComposition?.layers.map(\.id) ?? []
        guard order.contains(id) else { return }
        var picks = layerSelection.primary == selectedLayerID ? layerSelection : Selection(selectedLayerID.map { [$0] } ?? [])
        if picks.anchor == nil { picks.anchor = selectedLayerID }
        picks.pick(id, pick, order: order) { order.contains($0) }
        layerSelection = picks
        document.selectedLayerID = picks.primary
    }
}
