// PhotoSeveralLayers+Kernel.swift: Delete and Move on every picked layer
// (multi-layer-select). PM-2 stubs: both act on the primary alone, on the
// same paths Delete Layer and the Move tool use; PM-5 and PM-6 make them act
// on every picked layer as one undo step. Linux-safe: no UI imports.

extension PhotoWorkspace {
    /// Why Delete can't remove the picked layers: every layer is picked, and
    /// at least one must stay. Nil when it can.
    public var removeSelectedHelp: String? {
        !layers.isEmpty && selectedLayerIDs.count >= layers.count ? "At least one layer must stay." : nil
    }

    /// Removes the picked layers, refusing with `removeSelectedHelp` when they
    /// are every layer. Stub until PM-5: removes the primary alone.
    public mutating func removeSelectedLayers() {
        if let help = removeSelectedHelp {
            statusMessage = help
            return
        }
        guard let id = selectedLayerID else { return }
        removeLayer(id)
    }

    /// Moves the picked layers by (`dx`, `dy`) canvas pixels, one undo step.
    /// An adjustment layer has no place on the canvas and refuses. Stub until
    /// PM-6: moves the primary alone.
    public mutating func moveSelectedLayers(dx: Int, dy: Int) {
        let reach = -10_000_000...10_000_000
        guard dx != 0 || dy != 0, reach.contains(dx), reach.contains(dy),
            let id = selectedLayerID, let at = index(of: id)
        else { return }
        if case .adjustment = layers[at].kind {
            statusMessage = Self.moveRefusal
            return
        }
        recordLayers(named: "Move Layer")
        layers[at].offsetX += dx
        layers[at].offsetY += dy
        touch(.all)
    }
}
