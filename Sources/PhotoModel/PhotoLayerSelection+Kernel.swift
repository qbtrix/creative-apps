// PhotoLayerSelection+Kernel.swift: the picked layers in the Layers list, on
// SuiteKernel's Selection (multi-layer-select). `layerSelection` keeps them,
// primary last; `selectedLayerID` reads the primary. A Shift pick extends a
// range from the anchor through the list's top-first order, a Command pick
// toggles, and every change goes through the kernel's pick, selectAll, prune
// and replace; Photo only keeps the selection from emptying while there are
// layers. Linux-safe: no UI imports.
import SuiteKernel

extension PhotoWorkspace {
    /// The picked layers' ids, top first as the Layers list shows them.
    public var selectedLayerIDs: [PhotoLayer.ID] {
        layers.map(\.id).filter { layerSelection.contains($0) }
    }

    /// Applies one click on the Layers list's row `id`: `.replace`, `.extend`
    /// (Shift, a range from the anchor in list order) or `.toggle` (Command).
    /// An unknown id is ignored; toggling off the last picked layer keeps it.
    public mutating func pickLayer(_ id: PhotoLayer.ID, _ pick: Pick) {
        guard index(of: id) != nil else { return }
        layerSelection.pick(id, pick, order: layers.map(\.id))
        if layerSelection.ordered.isEmpty { layerSelection.replace([id]) }
    }

    /// Picks every layer; the primary stays the layer it was.
    public mutating func selectAllLayers() {
        let ids = layers.map(\.id), primary = layerSelection.primary.flatMap { ids.contains($0) ? $0 : nil }
        layerSelection.selectAll(ids.filter { $0 != primary } + (primary.map { [$0] } ?? []))
    }

    /// After the layer at `at` was removed: drops the ids that are gone; when
    /// none is left, picks the layer that took its place.
    mutating func pruneLayerSelection(near at: Int) {
        let live = Set(layers.map(\.id))
        layerSelection.prune(alive: live.contains)
        keepOneLayerPicked(layers.indices.contains(at) ? layers[at].id : layers.last?.id)
    }

    /// After an undo, a redo or a whole-stack restore that recorded `primary`:
    /// a step that changed the primary puts it back alone; otherwise the picks
    /// stay, minus the ids the step took away.
    mutating func restoreLayerSelection(primary: PhotoLayer.ID?) {
        if primary != layerSelection.primary { layerSelection.replace(primary.map { [$0] } ?? []) }
        let restored = Set(layers.map(\.id))
        layerSelection.prune { restored.contains($0) }
        keepOneLayerPicked(layers.first?.id)
    }

    /// Picks `fallback` when nothing is picked, so a stack with layers always
    /// has a selected one.
    private mutating func keepOneLayerPicked(_ fallback: PhotoLayer.ID?) {
        if layerSelection.primary == nil, let fallback { layerSelection.replace([fallback]) }
    }
}
