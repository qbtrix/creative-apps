// FlareSymbols.swift: the Library tab's symbols and editing a symbol in place (docs/blueprints/flare.md, 3.1 and 3.4).
// Each library edit is one undo step through `services.library`. Entering a symbol switches the owner to `.symbol`,
// gives the timeline the symbol's length, starts the playhead at its frame 0 and remembers the scene frame left;
// exiting returns there. An undo or redo that removes the edited symbol exits it the same way.
import FlareCore

extension FlareWorkspace {
    /// The layer list the stage, timeline and inspector edit: the symbol being edited, else the selected scene.
    public var editingOwner: LayerOwner? { editingSymbolID.map(LayerOwner.symbol) ?? selectedSceneID.map(LayerOwner.scene) }
    /// The symbol being edited in place; nil while editing the scene.
    public var editingSymbol: Symbol? { document?.symbols.first { $0.id == editingSymbolID } }
    /// How many frames the timeline shows: the edited symbol's, else the selected scene's, else 0.
    public var timelineDurationFrames: Int { editingSymbol?.durationFrames ?? selectedScene?.durationFrames ?? 0 }
    /// The breadcrumb while editing a symbol, "Scene 1" then the symbol's name; empty while editing the scene.
    public var symbolBreadcrumb: [String] { editingSymbol.map { [selectedScene?.name, $0.name].compactMap { $0 } } ?? [] }

    /// The Library tab's SYMBOLS rows, with usage counts.
    public var librarySymbols: [SymbolSummary] { document.map(services.library.symbols) ?? [] }

    /// Why symbol `id` can't be deleted, as the Delete button's tooltip; nil when it can.
    public func symbolRemoveHelp(_ id: String) -> String? {
        guard let row = librarySymbols.first(where: { $0.id == id }) else { return FlareLayerError.noDocument.message }
        return row.usage == 0 ? nil : "\(row.name) is used \(row.usage == 1 ? "once" : "\(row.usage) times")."
    }

    /// Turns the selected layers of the scene into a new symbol named `name`, in one step, and selects its instance.
    public mutating func convertToSymbol(named name: String) {
        guard let sceneID = selectedSceneID else { return refuse(.noDocument) }
        guard editingSymbolID == nil else { return refuse(.refused("Leave the symbol to convert scene art.")) }
        let picked = propertyLayerIDs
        // ConvertToSymbol keeps the first moved layer's id, in scene order, for the layer holding the instance.
        guard let host = selectedScene?.layers.first(where: { picked.contains($0.id) })?.id else {
            return refuse(.refused("Select art to convert first."))
        }
        let library = services.library
        step { _ = try library.convertToSymbol(picked, sceneID: sceneID, name: name, in: &$0) }
        if layerError == nil { setSelection([StageAddress(owner: .scene(sceneID), layerID: host, item: .instance(0))]) }
    }

    /// Places an instance of symbol `id` at `point` on the selected layer, in one step, and selects it.
    public mutating func placeSymbol(_ id: String, at point: Point) {
        guard let owner = editingOwner else { return refuse(.noDocument) }
        guard let layerID = propertyLayerIDs.last else {
            return refuse(.refused("Select a layer to place the symbol on."))
        }
        let library = services.library
        var placed: StageAddress?
        step { placed = try library.placeInstance(of: id, at: point, owner: owner, layerID: layerID, in: &$0) }
        if let placed, layerError == nil { setSelection([placed]) }
    }

    /// Renames symbol `id` in one step; a name of only whitespace is refused.
    public mutating func renameSymbol(_ id: String, to name: String) {
        let library = services.library
        step { try library.renameSymbol(id, to: name, in: &$0) }
    }

    /// Deletes symbol `id` in one step, refused with `symbolRemoveHelp` while an instance uses it.
    public mutating func removeSymbol(_ id: String) {
        if let reason = symbolRemoveHelp(id) { return refuse(.refused(reason)) }
        let library = services.library
        step { try library.removeSymbol(id, in: &$0) }
    }

    /// Edits symbol `id` in place from its frame 0, remembering the scene frame to return to. Entering a symbol
    /// from inside another keeps the scene frame first left.
    public mutating func enterSymbol(_ id: String) {
        guard document?.symbols.contains(where: { $0.id == id }) == true else {
            return refuse(.command(.symbolNotFound(id)))
        }
        guard id != editingSymbolID else { return }
        if editingSymbolID == nil { symbolReturnFrame = currentFrame }
        cancelDrag(); setSelection([])
        (isPlaying, playClock, editingSymbolID, currentFrame) = (false, 0, id, 0)
    }

    /// Return on the stage: edits the symbol of the selected instance; anything else selected does nothing.
    public mutating func editSelectedInstance() {
        guard let address = selection.last, case .instance(let i) = address.item,
              let instances = document?.layers(of: address.owner)?.first(where: { $0.id == address.layerID })?.instances,
              instances.indices.contains(i) else { return }
        enterSymbol(instances[i].symbolID)
    }

    /// Escape or the breadcrumb: back to the scene at the frame left, kept inside the scene's length.
    public mutating func exitSymbol() {
        guard editingSymbolID != nil else { return }
        let last = max((selectedScene?.durationFrames ?? 1) - 1, 0)
        cancelDrag(); setSelection([])
        (isPlaying, playClock, editingSymbolID) = (false, 0, nil)
        currentFrame = min(max(symbolReturnFrame ?? 0, 0), last)
        symbolReturnFrame = nil
    }

    /// Leaves the edited symbol once the document no longer has it (an undone convert, a redone delete).
    mutating func exitMissingSymbol() {
        if editingSymbolID != nil, editingSymbol == nil { exitSymbol() }
    }
}
