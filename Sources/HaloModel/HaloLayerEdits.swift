// HaloLayerEdits.swift: layer housekeeping in the selected composition:
// delete, rename, reorder and duplicate a layer, each one named undo step
// through `edit`. Every edit is refused with `.noComposition` without a
// composition; a refused or unchanged edit records nothing. Deleting a parent
// un-parents its children through `PropertyKeying.setParent(nil, …)`, so they
// keep their place on screen at the playhead. Linux-safe: no UI imports.

extension HaloProject {
    /// The layer list's identifier, where list-wide refusals show.
    static let layerListControl = "halo.layer.list"

    /// A layer row's identifier, where its rename refusal shows.
    static func layerRowControl(_ id: String) -> String { "halo.layer.row.\(id)" }

    /// Deletes the selected layer and selects the one that took its place
    /// (else the new bottom layer, else none). Its children stop following it
    /// and keep their place on screen; on a keying that can't parent yet
    /// (`.notBuilt`) they just lose the parent. Any other keying error refuses
    /// the delete. One step, "Delete Layer".
    public mutating func deleteSelectedLayer() {
        let keying = services.keying  // read before `edit`: its closure can't touch `self`
        edit("Delete Layer", control: Self.layerListControl) { doc in
            let (c, l) = try doc.selectedLayerIndices()
            var comp = doc.compositions[c]
            let id = comp.layers[l].id
            for child in comp.layers where child.parentID == id {
                do {
                    try keying.setParent(nil, of: child.id, at: comp.playheadFrame, in: &comp)
                } catch HaloEditError.notBuilt {
                    if let k = comp.layers.firstIndex(where: { $0.id == child.id }) { comp.layers[k].parentID = nil }
                }
            }
            comp.layers.removeAll { $0.id == id }
            doc.selectedLayerID = comp.layers.indices.contains(l) ? comp.layers[l].id : comp.layers.last?.id
            doc.compositions[c] = comp
        }
    }

    /// Renames layer `id`, the name normalized as composition names are
    /// (`normalizedName`). A blank name is refused with `.emptyName`, an
    /// unknown id with `.unknownLayer`, both under the layer's row. Names need
    /// not be unique. One step, "Rename Layer", unless the name is unchanged.
    public mutating func renameLayer(_ id: String, to name: String) {
        edit("Rename Layer", control: Self.layerRowControl(id)) { doc in
            let c = try doc.selectedCompositionIndex()
            let clean = name.normalizedName
            guard !clean.isEmpty else { throw HaloEditError.emptyName }
            guard let l = doc.compositions[c].layers.firstIndex(where: { $0.id == id }) else {
                throw HaloEditError.unknownLayer(id)
            }
            doc.compositions[c].layers[l].name = clean
        }
    }

    /// Moves layer `id` to `index` (top first), clamped to the list. One
    /// step, "Move Layer", unless it is already there.
    public mutating func moveLayer(_ id: String, to index: Int) {
        edit("Move Layer", control: Self.layerListControl) { doc in
            let c = try doc.selectedCompositionIndex()
            var layers = doc.compositions[c].layers
            guard let from = layers.firstIndex(where: { $0.id == id }) else { throw HaloEditError.unknownLayer(id) }
            let layer = layers.remove(at: from)
            layers.insert(layer, at: min(max(index, 0), layers.count))
            doc.compositions[c].layers = layers
        }
    }

    /// Moves the selected layer one place toward the top; nothing at the top.
    /// One step, "Move Layer".
    public mutating func bringSelectedLayerForward() { moveSelectedLayer(by: -1) }

    /// Moves the selected layer one place toward the bottom; nothing at the
    /// bottom. One step, "Move Layer".
    public mutating func sendSelectedLayerBackward() { moveSelectedLayer(by: 1) }

    /// Copies the selected layer directly above it as "<name> copy" with a new
    /// id (taken before the step, so an undone copy's id is never given
    /// again), everything else kept, and selects the copy. One step,
    /// "Duplicate Layer".
    public mutating func duplicateSelectedLayer() {
        let newID = selectedLayer == nil ? nil : selectedComposition.map { takeLayerID(in: $0.id) }
        edit("Duplicate Layer", control: Self.layerListControl) { doc in
            let (c, l) = try doc.selectedLayerIndices()
            guard let newID else { throw HaloEditError.noLayerSelected }
            let original = doc.compositions[c].layers[l]
            var copy = original.withID(newID)
            copy.name = "\(original.name) copy"
            doc.compositions[c].layers.insert(copy, at: l)
            doc.selectedLayerID = newID
        }
    }

    /// The final index of a row a list's move drops at `toOffset`: a row moved
    /// down lands one above the offset. Clamped to the list; nil when `from`
    /// is out of range.
    public static func moveTarget(from: Int, toOffset: Int, count: Int) -> Int? {
        guard (0..<max(count, 0)).contains(from) else { return nil }
        let target = toOffset > from ? toOffset - 1 : toOffset
        return min(max(target, 0), count - 1)
    }

    /// Swaps the selected layer with its neighbor `step` places down; nothing
    /// when there is none.
    private mutating func moveSelectedLayer(by step: Int) {
        edit("Move Layer", control: Self.layerListControl) { doc in
            let (c, l) = try doc.selectedLayerIndices()
            guard doc.compositions[c].layers.indices.contains(l + step) else { return }
            doc.compositions[c].layers.swapAt(l, l + step)
        }
    }
}

extension HaloDocumentState {
    /// The selected composition's index; `.noComposition` without one.
    fileprivate func selectedCompositionIndex() throws -> Int {
        guard let c = compositions.firstIndex(where: { $0.id == selectedCompositionID }) else {
            throw HaloEditError.noComposition
        }
        return c
    }

    /// The selected composition's and layer's indexes; `.noComposition` or
    /// `.noLayerSelected` without them.
    fileprivate func selectedLayerIndices() throws -> (composition: Int, layer: Int) {
        let c = try selectedCompositionIndex()
        guard let l = compositions[c].layers.firstIndex(where: { $0.id == selectedLayerID }) else {
            throw HaloEditError.noLayerSelected
        }
        return (c, l)
    }
}
