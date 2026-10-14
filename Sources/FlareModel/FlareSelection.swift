// FlareSelection.swift: the stage selection (blueprint section 2). Select picks layers, each kept as the hit item's
// address; Direct Select picks items. Shift adds or removes.
import FlareCore

extension FlareWorkspace {
    /// The selected layers' ids, each once, in the order they were picked.
    public var selectedLayerIDs: [String] {
        selection.map(\.layerID).reduce(into: []) { ids, id in if !ids.contains(id) { ids.append(id) } }
    }

    /// World bounds of every item on the selected layers (Select) or of the selected items; nil when none.
    public var selectionBounds: Rect? {
        guard let document, let sceneID = selectedSceneID, !selection.isEmpty else { return nil }
        let items = tool == .select
            ? services.stage.drawList(document, sceneID: sceneID, frame: currentFrame, editing: editingSymbolID)
                .items.map(\.address).filter { selectedLayerIDs.contains($0.layerID) }
            : selection
        return services.hits.bounds(document, sceneID: sceneID, frame: currentFrame, of: items)
    }

    /// Whether `address` counts as selected: its layer for Select, the item itself for Direct Select.
    func isSelected(_ address: StageAddress) -> Bool {
        tool == .select ? selectedLayerIDs.contains(address.layerID) : selection.contains(address)
    }

    /// Picks `address` as a click does: alone, or with `adding` toggled in or out of the selection.
    mutating func pick(_ address: StageAddress, adding: Bool) {
        guard adding else { return selection = isSelected(address) ? selection : [address] }
        guard isSelected(address) else { return selection.append(address) }
        selection.removeAll { tool == .select ? $0.layerID == address.layerID : $0 == address }
    }

    /// Drops selected addresses whose layer left the document, after an edit, undo or redo.
    mutating func dropMissingSelection() {
        guard let document else { return selection = [] }
        selection.removeAll { address in
            document.layers(of: address.owner)?.contains { $0.id == address.layerID } != true
        }
    }
}
