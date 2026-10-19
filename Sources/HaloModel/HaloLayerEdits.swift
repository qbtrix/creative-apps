// HaloLayerEdits.swift: layer housekeeping in the selected composition:
// delete, rename, reorder and duplicate a layer, each one named undo step
// through `edit`. Every edit is refused with `.noComposition` without a
// composition; a refused or unchanged edit records nothing. Deleting a parent
// un-parents its children through `PropertyKeying.setParent(nil, …)`, so they
// keep their place on screen at the playhead. Moves, bring/send and duplicate
// run on SuiteKernel's LayerTree (HaloLayers+Kernel). The layer list's rows
// and the command its drop makes live here too, so the view does no index
// math. Linux-safe: no UI imports.
import SuiteKernel

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
                    try comp.editLayerTree { tree in _ = tree.update(child.id) { $0.followsID = nil } }
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

    /// Moves layer `id` to `index` (top first), clamped to the list, through
    /// LayerTree.move. One step, "Move Layer", unless it is already there.
    public mutating func moveLayer(_ id: String, to index: Int) {
        edit("Move Layer", control: Self.layerListControl) { doc in
            let c = try doc.selectedCompositionIndex()
            // Top first among the others becomes back to front once the layer is out.
            let last = doc.compositions[c].layers.count - 1
            let at = last - min(max(index, 0), last)
            try doc.compositions[c].editLayerTree { (tree: inout LayerTree<HaloLayer>) throws(TreeRefusal) in
                try tree.move(id, into: nil, at: at)
            }
        }
    }

    /// Moves the selected layer one place toward the top; nothing at the top.
    /// One step, "Move Layer".
    public mutating func bringSelectedLayerForward() { arrangeSelectedLayer(.bringForward) }

    /// Moves the selected layer one place toward the bottom; nothing at the
    /// bottom. One step, "Move Layer".
    public mutating func sendSelectedLayerBackward() { arrangeSelectedLayer(.sendBackward) }

    /// Copies the selected layer directly above it as "<name> copy" with a new
    /// id (taken before the step, so an undone copy's id is never given
    /// again), everything else kept, and selects the copy, through
    /// LayerTree.duplicate. One step, "Duplicate Layer".
    public mutating func duplicateSelectedLayer() {
        let newID = selectedLayer == nil ? nil : selectedComposition.map { takeLayerID(in: $0.id) }
        edit("Duplicate Layer", control: Self.layerListControl) { doc in
            let (c, l) = try doc.selectedLayerIndices()
            guard let newID else { throw HaloEditError.noLayerSelected }
            let original = doc.compositions[c].layers[l]
            try doc.compositions[c].editLayerTree { (tree: inout LayerTree<HaloLayer>) throws(TreeRefusal) in
                guard tree.duplicate([original.id], mint: { newID }) == [newID] else { throw .unknown(original.id) }
                _ = tree.update(newID) { $0.name = "\(original.name) copy" }
            }
            doc.selectedLayerID = newID
        }
    }

    /// The layer list's rows (SuiteUI's LayerTreeList): the selected
    /// composition's layers top first, all on one level.
    public var layerRows: [LayerRow] { selectedComposition?.layerTree.rows(expanded: []) ?? [] }

    /// The command a drop in the layer list makes: layer `id` into `parent`
    /// (nil among the layers) at `index`, counted from the back among the
    /// other layers, as LayerTreeList's drop proposes it. It becomes
    /// `moveLayer` with the top-first index, clamped to the list. Halo's
    /// layers hold no children, so a drop into a layer, or of an id the
    /// selected composition doesn't hold, makes none.
    public func layerDropCommand(_ id: String, into parent: String?, at index: Int) -> HaloCommand? {
        guard parent == nil, let layers = selectedComposition?.layers, layers.contains(where: { $0.id == id }) else {
            return nil
        }
        let last = layers.count - 1
        return .moveLayer(id, to: last - min(max(index, 0), last))
    }

    /// Moves the selected layer one place by `step` through LayerTree.arrange;
    /// nothing when it is already at that end.
    private mutating func arrangeSelectedLayer(_ step: ArrangeStep) {
        edit("Move Layer", control: Self.layerListControl) { doc in
            let (c, l) = try doc.selectedLayerIndices()
            let id = doc.compositions[c].layers[l].id
            try doc.compositions[c].editLayerTree { (tree: inout LayerTree<HaloLayer>) throws(TreeRefusal) in
                try tree.arrange(step, [id])
            }
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
    /// `.noLayerSelected` without them. The one selection lookup every layer
    /// edit uses (text and color included).
    func selectedLayerIndices() throws -> (composition: Int, layer: Int) {
        let c = try selectedCompositionIndex()
        guard let l = compositions[c].layers.firstIndex(where: { $0.id == selectedLayerID }) else {
            throw HaloEditError.noLayerSelected
        }
        return (c, l)
    }
}
