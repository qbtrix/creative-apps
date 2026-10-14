// LiveScenes+Order.swift: the live scene editor, part two (docs/blueprints/flare/features/live-scenes.md, task SN-2).
// `renameScene` is FlareCore's own `RenameScene` ("Rename Scene"). `reorderScene` clamps the index into the scene
// list, as `FakeScenes` does, and runs `ReorderScene` inside a "Move Scene" group, the fake's undo name, so it is
// still one undo step. Both agree with `FakeScenes` on the fixtures.
import FlareCore

extension LiveScenes {
    public func renameScene(_ id: String, to name: String, in engine: inout CommandEngine) throws {
        try engine.perform(RenameScene(sceneID: id, name: name))
    }

    public func reorderScene(_ id: String, to index: Int, in engine: inout CommandEngine) throws {
        let scenes = engine.document.scenes
        guard scenes.contains(where: { $0.id == id }) else { throw CommandError.sceneNotFound(id) }
        // The scene exists, so the list has at least one entry and the range is never empty.
        let target = min(max(index, 0), scenes.count - 1)
        try engine.group("Move Scene") { try $0.perform(ReorderScene(sceneID: id, toIndex: target)) }
    }
}
