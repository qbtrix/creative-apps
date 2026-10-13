// FakeScenes.swift: SceneEditing over the real engine (docs/blueprints/flare.md, 6.3). Add, remove, timing
// and guides are FlareCore's own commands; rename, reorder and canvas swap in an edited copy through
// `FixtureEdit`. With `unavailable` set, reads are empty and every write throws that reason.
import FlareCore

public struct FakeScenes: SceneEditing {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    /// What `removeScene` throws for the only scene left.
    public static let lastSceneMessage = "An animation needs at least one scene."

    private func available() throws {
        if let unavailable { throw NotBuilt(reason: unavailable) }
    }

    private static func scene(_ id: String, _ name: String, _ preset: CanvasPreset) -> FlareScene {
        FlareScene(id: id, name: name, fps: preset.fps, durationFrames: preset.durationFrames,
                   width: preset.width, height: preset.height)
    }

    public func newDocument(_ preset: CanvasPreset) -> Document {
        guard unavailable == nil else { return Document() }
        return Document(scenes: [Self.scene("scene-1", "Scene 1", preset)])
    }

    public func addScene(_ preset: CanvasPreset, in engine: inout CommandEngine) throws -> String {
        try available()
        let scenes = engine.document.scenes
        // The smallest n past the count that no scene uses as an id or a name.
        var n = scenes.count + 1
        while scenes.contains(where: { $0.id == "scene-\(n)" || $0.name == "Scene \(n)" }) { n += 1 }
        try engine.perform(AddScene(scene: Self.scene("scene-\(n)", "Scene \(n)", preset)))
        return "scene-\(n)"
    }

    public func renameScene(_ id: String, to name: String, in engine: inout CommandEngine) throws {
        try edit("Rename Scene", id, in: &engine) { $0.name = name }
    }

    public func removeScene(_ id: String, in engine: inout CommandEngine) throws {
        try available()
        guard engine.document.scenes.contains(where: { $0.id == id }) else { throw CommandError.sceneNotFound(id) }
        guard engine.document.scenes.count > 1 else { throw CommandError.invalidDocument(Self.lastSceneMessage) }
        try engine.perform(RemoveScene(sceneID: id))
    }

    public func reorderScene(_ id: String, to index: Int, in engine: inout CommandEngine) throws {
        try available()
        try engine.perform(FixtureEdit("Move Scene", from: engine.document) { doc in
            guard let from = doc.scenes.firstIndex(where: { $0.id == id }) else { throw CommandError.sceneNotFound(id) }
            let scene = doc.scenes.remove(at: from)
            doc.scenes.insert(scene, at: min(max(index, 0), doc.scenes.count))
        })
    }

    public func setCanvas(_ id: String, width: Double, height: Double, background: FlareColor,
                          in engine: inout CommandEngine) throws {
        try edit("Set Canvas", id, in: &engine) {
            $0.width = width; $0.height = height; $0.background = background
        }
    }

    public func setTiming(_ id: String, fps: Int, durationFrames: Int, in engine: inout CommandEngine) throws {
        try available()
        try engine.perform(SetSceneTiming(sceneID: id, fps: fps, durationFrames: durationFrames))
    }

    public func addGuide(_ axis: Guide.Axis, at position: Double, sceneID: String,
                         in engine: inout CommandEngine) throws -> Int {
        try available()
        try engine.perform(AddGuide(sceneID: sceneID, axis: axis, position: position))
        return (engine.document.scenes.first { $0.id == sceneID }?.guides.count ?? 1) - 1
    }

    public func moveGuide(at index: Int, to position: Double, sceneID: String, coalesceKey: String?,
                          in engine: inout CommandEngine) throws {
        try available()
        try engine.perform(MoveGuide(sceneID: sceneID, index: index, position: position), coalesceKey: coalesceKey)
    }

    public func removeGuide(at index: Int, sceneID: String, in engine: inout CommandEngine) throws {
        try available()
        try engine.perform(RemoveGuide(sceneID: sceneID, index: index))
    }

    /// One `FixtureEdit` named `label` on scene `id`, or `sceneNotFound`.
    private func edit(_ label: String, _ id: String, in engine: inout CommandEngine,
                      _ change: (inout FlareScene) -> Void) throws {
        try available()
        try engine.perform(FixtureEdit(label, from: engine.document) { doc in
            guard let i = doc.scenes.firstIndex(where: { $0.id == id }) else { throw CommandError.sceneNotFound(id) }
            change(&doc.scenes[i])
        })
    }
}
