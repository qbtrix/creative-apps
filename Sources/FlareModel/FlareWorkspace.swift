// FlareWorkspace.swift: the state behind Flare's window (2D animation): a
// FlareCore CommandEngine over the open document, the selected scene and layer,
// and the active tool. Linux-safe. Every document edit goes through `apply`, so
// it is one undo step; a command that throws changes neither the document nor
// the selection and leaves its error in `layerError`. Every palette tool acts
// through `drag(from:to:)`; a tool that does nothing there stays disabled with
// `unavailableHelp` (FlareToolsTests checks this).
import FlareCore

/// The drawing tools on Flare's tool palette.
public enum FlareTool: String, CaseIterable, Sendable {
    case select, pen, rectangle, ellipse

    /// Why the palette shows this tool disabled, as its tooltip; nil once the
    /// tool works. Set it to nil in the change that makes `drag` do something.
    public var unavailableHelp: String? {
        switch self {
        case .select: "Selecting on the stage isn't built yet (#12)."
        case .pen: "Drawing paths isn't built yet."
        case .rectangle: "Drawing rectangles isn't built yet."
        case .ellipse: "Drawing ellipses isn't built yet."
        }
    }

    public var isEnabled: Bool { unavailableHelp == nil }
}

public struct FlareWorkspace: Sendable, Equatable {
    private var engine: CommandEngine?
    public private(set) var selectedSceneID: String?
    public private(set) var selectedLayerID: String?
    public private(set) var tool: FlareTool = .select
    /// Why the last layer change or undo was refused; nil after one succeeds.
    public private(set) var layerError: FlareLayerError?

    public init() {}

    public var document: Document? { engine?.document }

    public var scenes: [Scene] { document?.scenes ?? [] }

    public var selectedScene: Scene? {
        scenes.first { $0.id == selectedSceneID }
    }

    public var canUndo: Bool { engine?.canUndo ?? false }
    public var canRedo: Bool { engine?.canRedo ?? false }

    /// Replaces the open document with a new one holding one default scene in
    /// a fresh engine (no undo history), and selects that scene.
    public mutating func newDocument() {
        let scene = Scene(id: "scene-1", name: "Scene 1")
        engine = CommandEngine(document: Document(scenes: [scene]))
        selectedSceneID = scene.id
        selectedLayerID = nil
        layerError = nil
    }

    /// Selects a scene by id. An id not in the document is ignored. Selecting
    /// another scene clears the layer selection.
    public mutating func selectScene(_ id: String) {
        guard scenes.contains(where: { $0.id == id }), id != selectedSceneID else { return }
        selectedSceneID = id
        selectedLayerID = nil
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
    }

    /// The active tool's drag across the stage from `start` to `end`, in scene
    /// points; a click is a drag that doesn't move. The stage sends every tool
    /// gesture here, so each case is where that tool's work goes.
    public mutating func drag(from start: Point, to end: Point) {
        switch tool {
        case .select, .pen, .rectangle, .ellipse: break
        }
    }

    /// Undoes or redoes the last change; nothing to undo or redo is a no-op.
    public mutating func undo() { if canUndo { step { try $0.undo() } } }
    public mutating func redo() { if canRedo { step { try $0.redo() } } }

    /// Runs `command` as one undo step, then sets the layer selection to
    /// `selection` when it is `.layer`. On a throw nothing changes but `layerError`.
    mutating func apply(_ command: some Command, selection: FlareLayerSelection = .keep) {
        step { try $0.perform(command) }
        guard layerError == nil, case .layer(let id) = selection else { return }
        selectedLayerID = id
    }

    /// Reports `error` without touching the document or the selection.
    mutating func refuse(_ error: FlareLayerError) {
        layerError = error
    }

    /// Runs `body` on a copy of the engine and commits it only if it succeeds.
    /// Afterwards a selected layer that no longer exists is deselected.
    private mutating func step(_ body: (inout CommandEngine) throws -> Void) {
        guard var next = engine else { return refuse(.noDocument) }
        do {
            try body(&next)
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
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.document == rhs.document && lhs.selectedSceneID == rhs.selectedSceneID
            && lhs.selectedLayerID == rhs.selectedLayerID && lhs.tool == rhs.tool
            && lhs.layerError == rhs.layerError && lhs.canUndo == rhs.canUndo && lhs.canRedo == rhs.canRedo
    }
}
