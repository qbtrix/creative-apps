// FlareWorkspace.swift: the state behind Flare's window (2D animation). Holds
// the open FlareCore document, the selected scene and the active drawing tool.
// Linux-safe: no UI imports. FlareApp reads it and changes it only through the
// mutating methods here; stored state stays `private(set)`. Document edits go
// through FlareCore commands once the canvas lands. Every palette tool acts
// through `drag(from:to:)`; a tool that does nothing there stays disabled with
// `unavailableHelp` (FlareToolsTests checks this).
import FlareCore

/// The drawing tools on Flare's tool palette.
public enum FlareTool: String, CaseIterable, Sendable {
    case select, pen, rectangle, ellipse

    /// Why the palette shows this tool disabled, as its tooltip; nil once the
    /// tool works. Set it to nil in the change that makes `drag` do something.
    public var unavailableHelp: String? { nil }

    public var isEnabled: Bool { unavailableHelp == nil }
}

public struct FlareWorkspace: Sendable, Equatable {
    public private(set) var document: Document?
    public private(set) var selectedSceneID: String?
    public private(set) var tool: FlareTool = .select

    public init() {}

    public var scenes: [Scene] { document?.scenes ?? [] }

    public var selectedScene: Scene? {
        scenes.first { $0.id == selectedSceneID }
    }

    /// Replaces the open document with a new one holding one default scene,
    /// and selects that scene.
    public mutating func newDocument() {
        let scene = Scene(id: "scene-1", name: "Scene 1")
        document = Document(scenes: [scene])
        selectedSceneID = scene.id
    }

    /// Selects a scene by id. An id not in the document is ignored.
    public mutating func selectScene(_ id: String) {
        guard scenes.contains(where: { $0.id == id }) else { return }
        selectedSceneID = id
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
}
