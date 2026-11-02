// PhotoSeveralLayers+Kernel.swift: Hide and Show, Opacity, Delete and Move on
// every picked layer (multi-layer-select). A row that is picked acts for the
// whole selection, one undo step per gesture; an unpicked row acts alone, as
// before. PM-5 fills Hide, Opacity and Delete; PM-6 Move, by a Select move's drag
// and by `layer.move-by`. Linux-safe: no UI imports.

extension PhotoWorkspace {
    /// The layers a click on row `id` acts on: every picked layer, top first,
    /// when `id` is picked; otherwise `id` alone.
    func layersActedOn(from id: PhotoLayer.ID) -> [PhotoLayer.ID] {
        layerSelection.contains(id) ? selectedLayerIDs : [id]
    }

    /// Shows a hidden layer or hides a shown one. On a picked row every picked
    /// layer takes the clicked row's new state, as one "Hide Layers" or "Show
    /// Layers" step.
    public mutating func toggleVisibility(_ id: PhotoLayer.ID) {
        guard let at = index(of: id) else { return }
        let targets = layersActedOn(from: id), hide = layers[at].isVisible
        commitKernelLayers(
            Self.kernelEdited(layers) { tree in
                for target in targets { _ = tree.update(target) { $0.isHidden = hide } }
            },
            named: (hide ? "Hide Layer" : "Show Layer") + (targets.count > 1 ? "s" : ""))
    }

    /// Sets opacity from a percentage, clamped to 0...100, on every layer a
    /// click on `id` acts on. NaN is ignored. A run of opacity changes to the
    /// same layers is one undo step.
    public mutating func setOpacity(_ id: PhotoLayer.ID, percent: Double) {
        guard !percent.isNaN, index(of: id) != nil else { return }
        let opacity = min(max(percent, 0), 100) / 100
        let targets = layersActedOn(from: id).compactMap(index(of:)).filter { layers[$0].opacity != opacity }
        guard !targets.isEmpty else { return }
        recordLayers(named: "Layer Opacity", coalescing: "opacity-" + layersActedOn(from: id).joined(separator: ","))
        for at in targets { layers[at].opacity = opacity }
        touch(.all)
    }

    /// Why Delete can't remove the picked layers: every layer is picked, and
    /// at least one must stay. Nil when it can.
    public var removeSelectedHelp: String? {
        layers.isEmpty || selectedLayerIDs.count < layers.count ? nil : "At least one layer must stay."
    }

    /// Why Delete Layer can't run, for the Layers panel's button and the
    /// menu alike: no layer, the last layer, or every layer picked. Nil when
    /// it can.
    public var deleteLayersHelp: String? {
        selectedLayer == nil ? Self.noLayer : canRemoveLayer ? removeSelectedHelp : "The last layer can't be deleted."
    }

    /// Removes the picked layers as one step, refusing with
    /// `removeSelectedHelp` when they are every layer. One picked layer is
    /// Delete Layer; several are "Delete Layers", and the layer that took the
    /// top one's place is selected.
    public mutating func removeSelectedLayers() {
        if let help = removeSelectedHelp {
            statusMessage = help
            return
        }
        let picked = selectedLayerIDs
        guard picked.count > 1, let top = picked.first.flatMap(index(of:)) else {
            if let id = selectedLayerID { removeLayer(id) }
            return
        }
        record(.stack(stackState), named: "Delete Layers")
        let gone = Set(picked)
        layers.removeAll { gone.contains($0.id) }
        for id in picked {
            pixels[id] = nil
            layerGeometryChanged(id, .removed)
        }
        selectedLayerID = layers.isEmpty ? nil : layers[min(top, layers.count - 1)].id
        touch(.all)
    }

    /// Where the picked layers that can move sit in `layers`, top first: an
    /// adjustment layer has no place on the canvas and stays put. Empty with
    /// no image layer picked.
    var movableSelectedLayers: [Int] {
        selectedLayerIDs.compactMap(index(of:)).filter {
            if case .adjustment = layers[$0].kind { return false }
            return true
        }
    }

    /// Moves the picked layers by (`dx`, `dy`) canvas pixels as one "Move
    /// Layers" step ("Move Layer" for one). Picked adjustment layers stay put;
    /// with no image layer picked it refuses with `moveRefusal`.
    public mutating func moveSelectedLayers(dx: Int, dy: Int) {
        let reach = -10_000_000...10_000_000
        guard dx != 0 || dy != 0, reach.contains(dx), reach.contains(dy), selectedLayerID != nil else { return }
        let targets = movableSelectedLayers
        guard !targets.isEmpty else {
            statusMessage = Self.moveRefusal
            return
        }
        recordLayers(named: targets.count > 1 ? "Move Layers" : "Move Layer")
        for at in targets {
            layers[at].offsetX += dx
            layers[at].offsetY += dy
        }
        touch(.all)
    }
}
