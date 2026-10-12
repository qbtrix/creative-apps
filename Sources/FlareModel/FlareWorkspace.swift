// FlareWorkspace.swift: the state behind Flare's window (2D animation). Holds
// the open FlareCore document, the selected scene and the active drawing tool.
// Linux-safe: no UI imports. FlareApp reads it and changes it only through the
// mutating methods here; stored state stays `private(set)`. Document edits go
// through FlareCore commands once the canvas lands.
import FlareCore

/// The drawing tools on Flare's tool palette.
public enum FlareTool: String, CaseIterable, Sendable {
    case select, pen, rectangle, ellipse
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
}
