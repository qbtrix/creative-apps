// FlareWorkspace.swift: the state behind Flare's window (2D animation): a
// FlareCore CommandEngine over the open document, the selected scene and layer,
// and the active tool. Linux-safe. Every document edit goes through `apply`, so
// it is one undo step; a command that throws changes neither the document nor
// the selection and leaves its error in `layerError`. Every palette tool acts
// through `drag`, then `endDrag`; a tool that does nothing there has `toolHelp`
// saying why (FlareToolsTests checks this). The easing editor's segment
// selection and drag serial live here too (FlareEasing.swift uses them); a
// change of layer selection drops the segment. Stored state is `internal(set)`
// so each area's extension file (docs/blueprints/flare.md, section 2) can set it.
import FlareCore

/// The drawing tools on Flare's tool palette.
public enum FlareTool: String, CaseIterable, Sendable {
    case select, directSelect, pen, rectangle, ellipse

    /// Why the palette shows this tool disabled, as its tooltip; nil once the
    /// stage sends it drags. `FlareWorkspace.toolHelp(_:)` falls back to it.
    public var unavailableHelp: String? {
        switch self {
        case .select: "Selecting on the stage isn't built yet (#12)."
        case .directSelect: "Direct selection on the stage isn't wired up yet."
        case .pen: "Drawing paths isn't built yet."
        case .rectangle: "Drawing rectangles isn't built yet."
        // The ellipse logic works (`drag`, `dragChanged`), but the stage
        // doesn't send drags yet; set this to nil when it does.
        case .ellipse: "Drawing ellipses on the stage isn't wired up yet."
        }
    }

    public var isEnabled: Bool { unavailableHelp == nil }
}

public struct FlareWorkspace: Sendable, Equatable {
    var engine: CommandEngine?
    /// The use cases the workspace edits through; `.live` or `.fake()`.
    public internal(set) var services: FlareServices
    public internal(set) var selectedSceneID: String?
    public internal(set) var selectedLayerID: String? {
        didSet { if oldValue != selectedLayerID { easingSelection = nil; easingDragSerial &+= 1 } }
    }
    public internal(set) var tool: FlareTool = .select
    /// The stage selection (FlareSelection.swift).
    public internal(set) var selection: [StageAddress] = []
    /// The marquee under way, in scene points; nil when none is.
    public internal(set) var marquee: Rect?
    /// The shape the drag under way would add, for the live preview; nil
    /// when no drag is running or the active tool draws nothing.
    public internal(set) var draft: ShapeDraft?
    /// The stage with the move under way applied; nil when none is.
    public internal(set) var dragPreview: StageDrawList?
    /// The pointer gesture under way (FlareDrag.swift).
    var gesture: StageGesture?
    /// The playhead (FlarePlayback.swift).
    public internal(set) var currentFrame = 0
    /// Playback: running or not, wrapping at the end or stopping, and the
    /// seconds played since it started (FlarePlayback.swift).
    public internal(set) var isPlaying = false
    public internal(set) var loops = true
    public internal(set) var playClock: Double = 0
    /// Whether an edit to a not-animated property keys the playhead (FlareAnimate.swift).
    public internal(set) var autoKey = false
    /// Onion skin and motion path overlays (FlareOnionState.swift).
    public internal(set) var onion = OnionSettings()
    public internal(set) var showsMotionPath = false
    /// The symbol being edited in place; nil edits the scene (FlareSymbols.swift).
    public internal(set) var editingSymbolID: String?
    /// The scene frame to return to when the symbol edit ends.
    var symbolReturnFrame = 0
    /// The Interactions editor's machine, its live preview, and why the last
    /// machine edit or preview failed (FlareMachines.swift).
    public internal(set) var machineID: String?
    public internal(set) var machinePreview: MachinePreview?
    public internal(set) var machineError: String?
    /// The export sheet's run (FlareExport.swift) and the Assist popover (FlareAssist.swift).
    public internal(set) var exportState = ExportState.idle
    public internal(set) var assist = AssistState()
    /// The open file's name, unsaved changes, the last save failure, the
    /// open under way, and recently opened files (FlareFiles.swift).
    public internal(set) var fileName: String?
    public internal(set) var isDirty = false
    public internal(set) var saveError: String?
    public internal(set) var loadState = LoadState.idle
    public internal(set) var recent: [String] = []
    /// Why the last layer change or undo was refused; nil after one succeeds.
    public internal(set) var layerError: FlareLayerError?
    /// The easing editor's segment, as last picked; `selectedEasingSegment`
    /// reads it only while the selected layer still has that segment.
    var easingSelection: EasingSegment?
    /// Part of a handle drag's coalesce key; bumped to end the drag.
    var easingDragSerial = 0
    /// Part of a property scrub's coalesce key; bumped to end the scrub.
    var propertyScrubSerial = 0
    /// Part of a guide drag's coalesce key; bumped to end the drag.
    var guideDragSerial = 0

    public init(services: FlareServices = .live) {
        self.services = services
    }

    public var document: Document? { engine?.document }

    public var scenes: [Scene] { document?.scenes ?? [] }

    public var selectedScene: Scene? {
        scenes.first { $0.id == selectedSceneID }
    }

    public var canUndo: Bool { engine?.canUndo ?? false }
    public var canRedo: Bool { engine?.canRedo ?? false }
    /// "Undo Set Keyframe Easing", for the Edit menu; nil with nothing to undo.
    public var undoActionName: String? { engine?.undoActionName }
    public var redoActionName: String? { engine?.redoActionName }

    /// Replaces the open document with a new one holding one default scene in
    /// a fresh engine (no undo history), and selects that scene.
    public mutating func newDocument() {
        load(Document(scenes: [Scene(id: "scene-1", name: "Scene 1")]))
    }

    /// Opens `document` in a fresh engine (no undo history), selects its
    /// first scene, and clears the per-document state: selections, drafts,
    /// playback, the symbol and machine being edited, export, assist and the
    /// file's name and save state. Tool, loop, auto-key, onion, motion path
    /// and the recent list are preferences and stay.
    mutating func load(_ document: Document) {
        engine = CommandEngine(document: document)
        selectedSceneID = document.scenes.first?.id
        selectedLayerID = nil
        easingSelection = nil
        layerError = nil
        cancelDrag(); selection = []; currentFrame = 0
        (isPlaying, playClock, editingSymbolID, symbolReturnFrame) = (false, 0, nil, 0)
        (machineID, machinePreview, machineError) = (nil, nil, nil)
        (exportState, assist) = (.idle, AssistState())
        (fileName, isDirty, saveError, loadState) = (nil, false, nil, .idle)
    }

    /// Selects a scene by id. An id not in the document is ignored. Selecting
    /// another scene clears the layer selection, stops playback and keeps the
    /// playhead on the new scene's timeline (#615).
    public mutating func selectScene(_ id: String) {
        guard scenes.contains(where: { $0.id == id }), id != selectedSceneID else { return }
        selectedSceneID = id
        selectedLayerID = nil
        cancelDrag(); selection = []
        pause(); clampPlayhead()
    }

    /// Selects the scene that took removed scene `id`'s place in `order`, or the last one when it was last; with no
    /// scenes left, nothing.
    private mutating func selectNeighbour(of id: String, in order: [String]) {
        let ids = Set(scenes.map(\.id)), i = order.firstIndex(of: id) ?? 0
        let after = order.dropFirst(i).first(where: ids.contains), before = order.prefix(i).last(where: ids.contains)
        selectedSceneID = nil
        if let next = after ?? before ?? scenes.first?.id { selectScene(next) }
    }

    /// Selects a layer of the edited owner (the symbol being edited in place, else the selected scene) by id. An
    /// unknown id is ignored.
    public mutating func selectLayer(_ id: String) {
        guard ownerLayers?.contains(where: { $0.id == id }) == true else { return }
        selectedLayerID = id
    }

    /// Selects a sidebar row: a scene or a layer of the edited owner.
    public mutating func selectItem(_ id: String) {
        if scenes.contains(where: { $0.id == id }) {
            selectScene(id)
            selectedLayerID = nil
        } else {
            selectLayer(id)
        }
    }

    public mutating func selectTool(_ tool: FlareTool) {
        self.tool = tool
        cancelDrag()
    }

    /// Undoes or redoes the last change; nothing to undo or redo is a no-op. A step that changes the machines stops
    /// the machine preview, and an edited machine the document no longer has leaves nothing edited (#658).
    public mutating func undo() { if canUndo { historyStep { try $0.undo() } } }
    public mutating func redo() { if canRedo { historyStep { try $0.redo() } } }

    /// Runs `command` as one undo step, then sets the layer selection to
    /// `selection` when it is `.layer`. On a throw nothing changes but `layerError`.
    /// Consecutive commands with the same non-nil `coalesceKey` share one step.
    mutating func apply(
        _ command: some Command, selection: FlareLayerSelection = .keep, coalesceKey: String? = nil
    ) {
        step { try $0.perform(command, coalesceKey: coalesceKey) }
        guard layerError == nil, case .layer(let id) = selection else { return }
        selectedLayerID = id
    }

    /// Runs `body` as one undo step named `label`, then sets the layer
    /// selection like `apply`. On a throw nothing changes but `layerError`.
    mutating func applyGroup(
        _ label: String, selection: FlareLayerSelection = .keep, _ body: (inout CommandEngine) throws -> Void
    ) {
        step(label, body)
        guard layerError == nil, case .layer(let id) = selection else { return }
        selectedLayerID = id
    }

    /// Reports `error` without touching the document or the selection.
    mutating func refuse(_ error: FlareLayerError) {
        layerError = error
    }

    /// Runs `body` on a copy of the engine and commits it only if it succeeds.
    /// With a `label`, `body` runs inside `engine.group(label)`: only for
    /// workspace-level compositions such as Cut, since a contract opens its
    /// own group. Afterwards a selected scene that no longer exists (an undone Add Scene, a redone Delete Scene)
    /// gives way to its neighbour, clamped to the scene list, a selected layer the edited owner no longer has is
    /// deselected, a playhead past a shortened timeline moves to its last frame (#615), and a running play whose
    /// rate changed stays on its frame (#640).
    /// A symbol being edited in place that no longer exists ends the edit, as `exitSymbol` does (#603).
    mutating func step(_ label: String? = nil, _ body: (inout CommandEngine) throws -> Void) {
        guard var next = engine else { return refuse(.noDocument) }
        let order = scenes.map(\.id), fps = playbackFPS
        do {
            if let label { try next.group(label, body) } else { try body(&next) }
        } catch let error as CommandError {
            return refuse(.command(error))
        } catch {
            return refuse(.command(.invalidDocument("\(error)")))
        }
        engine = next
        layerError = nil
        if editingSymbolID != nil, editingSymbol == nil { exitSymbol() }
        if let id = selectedSceneID, selectedScene == nil { selectNeighbour(of: id, in: order) }
        if let id = selectedLayerID, ownerLayers?.contains(where: { $0.id == id }) != true {
            selectedLayerID = nil
        }
        clampPlayhead(rateWas: fps)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        let editing = lhs.document == rhs.document && lhs.selectedSceneID == rhs.selectedSceneID
            && lhs.selectedLayerID == rhs.selectedLayerID && lhs.tool == rhs.tool
            && lhs.draft == rhs.draft
            && lhs.layerError == rhs.layerError && lhs.selectedEasingSegment == rhs.selectedEasingSegment && lhs.canUndo == rhs.canUndo && lhs.canRedo == rhs.canRedo
            && lhs.services.isPreview == rhs.services.isPreview && lhs.selection == rhs.selection
            && lhs.marquee == rhs.marquee && lhs.dragPreview == rhs.dragPreview && lhs.gesture == rhs.gesture && lhs.currentFrame == rhs.currentFrame
        let animating = lhs.isPlaying == rhs.isPlaying && lhs.loops == rhs.loops && lhs.playClock == rhs.playClock
            && lhs.autoKey == rhs.autoKey && lhs.onion == rhs.onion && lhs.showsMotionPath == rhs.showsMotionPath
            && lhs.editingSymbolID == rhs.editingSymbolID && lhs.symbolReturnFrame == rhs.symbolReturnFrame
        let panels = lhs.machineID == rhs.machineID && lhs.machinePreview == rhs.machinePreview
            && lhs.machineError == rhs.machineError && lhs.exportState == rhs.exportState && lhs.assist == rhs.assist
        let files = lhs.fileName == rhs.fileName && lhs.isDirty == rhs.isDirty && lhs.saveError == rhs.saveError
            && lhs.loadState == rhs.loadState && lhs.recent == rhs.recent
        return editing && animating && panels && files
    }
}
