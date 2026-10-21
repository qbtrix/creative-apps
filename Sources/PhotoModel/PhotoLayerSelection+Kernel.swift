// PhotoLayerSelection+Kernel.swift: the picked layers in the Layers list, on
// SuiteKernel's Selection (multi-layer-select). `layerSelection` keeps them,
// primary last; `selectedLayerID` reads the primary. PM-2 stubs: a pick
// replaces the selection with the clicked row, as before; PM-4 fills in the
// Shift range, the Command toggle and the pruning. Linux-safe: no UI imports.
import SuiteKernel

extension PhotoWorkspace {
    /// The picked layers' ids, top first as the Layers list shows them.
    public var selectedLayerIDs: [PhotoLayer.ID] {
        layers.map(\.id).filter { layerSelection.contains($0) }
    }

    /// Applies one click on the Layers list's row `id`: `.replace`, `.extend`
    /// (Shift) or `.toggle` (Command). An unknown id is ignored. Stub until
    /// PM-4: every pick replaces the selection with the clicked row.
    public mutating func pickLayer(_ id: PhotoLayer.ID, _ pick: Pick) {
        guard index(of: id) != nil else { return }
        layerSelection.pick(id, .replace)
    }

    /// Picks every layer; the primary stays the layer it was.
    public mutating func selectAllLayers() {
        let ids = layers.map(\.id), primary = layerSelection.primary.flatMap { ids.contains($0) ? $0 : nil }
        layerSelection.selectAll(ids.filter { $0 != primary } + (primary.map { [$0] } ?? []))
    }
}
