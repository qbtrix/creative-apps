// FlareSymbols.swift: the Library tab and editing a symbol in place (docs/blueprints/flare.md, sections 3.1 and 3.4).
// Entering a symbol switches every owner-aware call to `.symbol(id)` (through `propertyOwner`), runs the timeline over
// the symbol's own frames from its first, and remembers the scene frame; exiting returns to that frame. Convert and
// place go through `services.library`, one named undo step each.
import FlareCore

extension FlareWorkspace {
    static let convertNeedsArtMessage = "Select art to convert to a symbol."
    static let convertInSymbolMessage = "Exit the symbol to convert scene art."
    static let moveInSymbolMessage = "Exit the symbol to move whole layers; Direct Select moves the symbol's art."
    static let placeNeedsLayerMessage = "Select a layer to place the symbol on."
    static let noInstanceMessage = "Select a symbol instance to edit it."

    /// The Library tab's SYMBOLS rows: name, usage and duration.
    public var librarySymbols: [SymbolSummary] { document.map(services.library.symbols) ?? [] }
    /// The Library tab's SWATCHES chips.
    public var swatches: [Swatch] { document.map(services.library.swatches) ?? [] }

    /// The symbol being edited in place, while it still exists.
    public var editingSymbol: Symbol? { document?.symbols.first { $0.id == editingSymbolID } }

    /// How many frames the timeline shows: the edited symbol's, else the selected scene's.
    public var timelineFrames: Int {
        max(editingSymbol?.durationFrames ?? selectedScene?.durationFrames ?? 0, 0)
    }

    /// The breadcrumb: the scene's name, then the edited symbol's ("Scene 1 › Wave").
    public var breadcrumb: [String] {
        (selectedScene.map { [$0.name] } ?? []) + (editingSymbol.map { [$0.name] } ?? [])
    }

    /// Delete's reason to be disabled: "<name> is used n times." while any instance uses the symbol; nil otherwise.
    public func removeSymbolHelp(_ id: String) -> String? {
        guard let s = librarySymbols.first(where: { $0.id == id }), s.usage > 0 else { return nil }
        return "\(s.name) is used \(s.usage) \(s.usage == 1 ? "time" : "times")."
    }

    /// Object > Convert to Symbol: moves the inspected scene layers into a new symbol named `name`, in one step, and
    /// selects the layer holding its instance. Returns the symbol's id, or nil when it refused.
    @discardableResult
    public mutating func convertToSymbol(named name: String) -> String? {
        guard editingSymbolID == nil else { refuse(.refused(Self.convertInSymbolMessage)); return nil }
        guard let sceneID = selectedSceneID else { refuse(.noDocument); return nil }
        let order = selectedScene?.layers.map(\.id) ?? []
        let layers = order.filter(propertyLayerIDs.contains)
        guard let host = layers.first else { refuse(.refused(Self.convertNeedsArtMessage)); return nil }
        let library = services.library
        var id: String?
        step { id = try library.convertToSymbol(layers, sceneID: sceneID, name: name, in: &$0) }
        guard let id, layerError == nil else { return nil }
        selection = []
        selectedLayerID = host
        return id
    }

    /// Places an instance of the symbol `id` at `point` on the inspected layer, in one step.
    public mutating func placeSymbol(_ id: String, at point: Point) {
        guard let owner = propertyOwner else { return refuse(.noDocument) }
        let layers = propertyLayerIDs
        guard layers.count == 1, let layerID = layers.first else { return refuse(.refused(Self.placeNeedsLayerMessage)) }
        let library = services.library
        step { _ = try library.placeInstance(of: id, at: point, owner: owner, layerID: layerID, in: &$0) }
    }

    /// Edit Symbol: edits the symbol `id` in place from its first frame. From the scene, the playhead's frame is
    /// kept for `exitSymbol`. An unknown id is ignored. A refusal from the old context is cleared (#686).
    public mutating func editSymbol(_ id: String) {
        guard document?.symbols.contains(where: { $0.id == id }) == true else { return }
        if editingSymbolID == nil { symbolReturnFrame = currentFrame }
        cancelDrag()
        (editingSymbolID, selection, selectedLayerID, layerError) = (id, [], nil, nil)
        (currentFrame, isPlaying, playClock) = (0, false, 0)
    }

    /// Return on the stage: edits the symbol of the one selected instance.
    public mutating func editSelectedInstance() {
        guard selection.count == 1, let address = selection.first, case .instance(let k) = address.item,
              let layer = document?.layers(of: address.owner)?.first(where: { $0.id == address.layerID }),
              layer.instances.indices.contains(k) else { return refuse(.refused(Self.noInstanceMessage)) }
        editSymbol(layer.instances[k].symbolID)
    }

    /// Exit Symbol (Escape or the breadcrumb): back to the scene at the frame it left. A refusal from inside the
    /// symbol, such as "Exit the symbol…", is cleared (#686).
    public mutating func exitSymbol() {
        guard editingSymbolID != nil else { return }
        cancelDrag()
        (editingSymbolID, selection, selectedLayerID, layerError) = (nil, [], nil, nil)
        (isPlaying, playClock) = (false, 0)
        currentFrame = min(symbolReturnFrame, max(timelineFrames - 1, 0))
    }
}
