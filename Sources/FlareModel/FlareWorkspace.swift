// FlareWorkspace.swift: the state behind Flare's window (2D animation): a
// FlareCore CommandEngine over the open document, the selected scene and layer,
// and the active tool. Linux-safe. Every document edit goes through `apply`, so
// it is one undo step; a command that throws changes neither the document nor
// the selection and leaves its error in `layerError`. Every palette tool acts
// through `drag(from:to:)`; a tool that does nothing there stays disabled with
// `toolHelp` (FlareToolsTests checks this). The easing editor's segment
// selection and drag serial live here too (FlareEasing.swift uses them); a
// change of layer selection drops the segment. The Ellipse tool's draft and
// commit are in FlareDrawing.swift.
import FlareCore

/// The drawing tools on Flare's tool palette.
public enum FlareTool: String, CaseIterable, Sendable {
    case select, directSelect, pen, rectangle, ellipse

    /// Why the palette shows this tool disabled, as its tooltip; nil once the
    /// tool works. Set it to nil in the change that makes the stage send drags.
    public var unavailableHelp: String? {
        switch self {
        case .select: "Selecting on the stage isn't wired up yet."
        case .directSelect: "Selecting parts of a shape on the stage isn't wired up yet."
        case .pen: "Drawing paths on the stage isn't wired up yet."
        case .rectangle: "Drawing rectangles on the stage isn't wired up yet."
        case .ellipse: "Drawing ellipses on the stage isn't wired up yet."
        }
    }

    public var isEnabled: Bool { unavailableHelp == nil }
}

public struct FlareWorkspace: Sendable, Equatable {
    public internal(set) var services: FlareServices
    var engine: CommandEngine?
    public internal(set) var selectedSceneID: String?
    public internal(set) var selectedLayerID: String? {
        didSet { if oldValue != selectedLayerID { easingSelection = nil; easingDragSerial &+= 1 } }
    }
    public internal(set) var tool: FlareTool = .select
    /// The stage selection: layers (Select) or items (Direct Select) (FlareSelection.swift).
    public internal(set) var selection: [StageAddress] = []
    /// What the drag under way would add, for the live preview (FlareDrag.swift).
    public internal(set) var shapeDraft: ShapeDraft?
    /// The stage as a select drag under way would leave it; nil otherwise.
    public internal(set) var dragPreview: StageDrawList?
    /// The gesture under way, for `endDrag` (FlareDrag.swift).
    var gesture: DragGesture?
    public internal(set) var currentFrame = 0
    public internal(set) var autoKey = false
    /// The symbol being edited in place; nil edits the scene (FlareSymbols.swift).
    public internal(set) var editingSymbolID: String?
    /// Why the last layer change or undo was refused; nil after one succeeds.
    public internal(set) var layerError: FlareLayerError?
    /// The easing editor's segment, as last picked; `selectedEasingSegment`
    /// reads it only while the selected layer still has that segment.
    var easingSelection: EasingSegment?
    /// Part of a handle drag's coalesce key; bumped to end the drag.
    var easingDragSerial = 0

    /// No arguments is the empty state on the fakes until IN-9 (blueprint 6.3).
    public init(services: FlareServices = .fake()) {
        self.services = services
    }

    /// The shape the drag under way would add; `shapeDraft`'s shape.
    public var draft: FlareShape? { shapeDraft?.shape }

    /// Why `tool` is disabled, as its tooltip; nil when it works. Its service's
    /// reason first, then `FlareTool.unavailableHelp` (the stage's wiring).
    public func toolHelp(_ tool: FlareTool) -> String? {
        services.shapes.unavailableHelp(for: tool) ?? tool.unavailableHelp
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
    /// first scene and clears the selections, the gesture and the frame.
    mutating func load(_ document: Document) {
        engine = CommandEngine(document: document)
        selectedSceneID = document.scenes.first?.id
        selectedLayerID = nil
        easingSelection = nil
        layerError = nil
        selection = []
        currentFrame = 0
        editingSymbolID = nil
        cancelDrag()
    }

    /// Selects a scene by id. An id not in the document is ignored. Selecting
    /// another scene clears the layer selection.
    public mutating func selectScene(_ id: String) {
        guard scenes.contains(where: { $0.id == id }), id != selectedSceneID else { return }
        selectedSceneID = id
        selectedLayerID = nil
        selection = []
        cancelDrag()
    }

    /// Selects a layer of the selected scene by id. An unknown id is ignored.
    public mutating func selectLayer(_ id: String) {
        guard selectedScene?.layers.contains(where: { $0.id == id }) == true else { return }
        selectedLayerID = id
    }

    /// Selects a sidebar row: a scene or a layer of the selected scene.
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

    /// Undoes or redoes the last change; nothing to undo or redo is a no-op.
    public mutating func undo() { if canUndo { step { try $0.undo() } } }
    public mutating func redo() { if canRedo { step { try $0.redo() } } }

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

    /// Runs `body` on a copy of the engine and commits it only if it succeeds;
    /// with a `label`, inside `engine.group(label)` (only for workspace-level
    /// compositions such as Cut; a contract's write opens its own group).
    /// Afterwards a selected layer or stage item that no longer exists is deselected.
    mutating func step(_ label: String? = nil, _ body: (inout CommandEngine) throws -> Void) {
        guard var next = engine else { return refuse(.noDocument) }
        do {
            if let label { try next.group(label, body) } else { try body(&next) }
        } catch let error as CommandError {
            return refuse(.command(error))
        } catch {
            return refuse(.command(.invalidDocument("\(error)")))
        }
        engine = next
        layerError = nil
        if let id = selectedLayerID, selectedScene?.layers.contains(where: { $0.id == id }) != true {
            selectedLayerID = nil
        }
        dropMissingSelection()
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.document == rhs.document && lhs.selectedSceneID == rhs.selectedSceneID
            && lhs.selectedLayerID == rhs.selectedLayerID && lhs.tool == rhs.tool
            && lhs.selection == rhs.selection && lhs.shapeDraft == rhs.shapeDraft
            && lhs.dragPreview == rhs.dragPreview && lhs.gesture == rhs.gesture && lhs.currentFrame == rhs.currentFrame
            && lhs.autoKey == rhs.autoKey && lhs.editingSymbolID == rhs.editingSymbolID
            && lhs.layerError == rhs.layerError && lhs.selectedEasingSegment == rhs.selectedEasingSegment && lhs.canUndo == rhs.canUndo && lhs.canRedo == rhs.canRedo
    }
}
