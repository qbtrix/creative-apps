// LiveScenes.swift: the live scene editor, part one (docs/blueprints/flare/features/live-scenes.md, task SN-1).
// `newDocument` opens one "Scene 1" sized by the preset; `addScene` and `removeScene` are FlareCore's own
// `AddScene` ("Add Scene") and `RemoveScene` ("Delete Scene"), one undo step each, and the last scene never goes.
// SN-2 to SN-4 add the other writes in their own files; SN-5 adds the `SceneEditing` conformance. Agrees with
// `FakeScenes` on the fixtures.
import FlareCore

public struct LiveScenes: Sendable {
    public init() {}

    private static func scene(_ id: String, _ name: String, _ preset: CanvasPreset) -> FlareScene {
        FlareScene(id: id, name: name, fps: preset.fps, durationFrames: preset.durationFrames,
                   width: preset.width, height: preset.height)
    }

    public func newDocument(_ preset: CanvasPreset) -> Document {
        Document(scenes: [Self.scene("scene-1", "Scene 1", preset)])
    }

    public func addScene(_ preset: CanvasPreset, in engine: inout CommandEngine) throws -> String {
        let scenes = engine.document.scenes
        // The smallest n past the count that no scene uses as an id or a name.
        var n = scenes.count + 1
        while scenes.contains(where: { $0.id == "scene-\(n)" || $0.name == "Scene \(n)" }) { n += 1 }
        try engine.perform(AddScene(scene: Self.scene("scene-\(n)", "Scene \(n)", preset)))
        return "scene-\(n)"
    }

    public func removeScene(_ id: String, in engine: inout CommandEngine) throws {
        guard engine.document.scenes.contains(where: { $0.id == id }) else { throw CommandError.sceneNotFound(id) }
        guard engine.document.scenes.count > 1 else { throw CommandError.invalidDocument(FakeScenes.lastSceneMessage) }
        try engine.perform(RemoveScene(sceneID: id))
    }
}
