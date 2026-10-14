// LiveScenes+Guides.swift: the live scene editor, part four (docs/blueprints/flare/features/live-scenes.md, task SN-4).
// `addGuide`, `moveGuide` and `removeGuide` are FlareCore's own `AddGuide`, `MoveGuide` and `RemoveGuide`, one undo
// step each. `moveGuide` runs at the top level with the caller's coalesce key, so the steps of one drag merge
// (`MoveGuide.merge`, LC-10) into one "Move Guide" entry. Agrees with `FakeScenes` on the fixtures.
import FlareCore

extension LiveScenes {
    /// Appends a guide and returns its index, as `FakeScenes` does.
    public func addGuide(_ axis: Guide.Axis, at position: Double, sceneID: String,
                         in engine: inout CommandEngine) throws -> Int {
        try engine.perform(AddGuide(sceneID: sceneID, axis: axis, position: position))
        return (engine.document.scenes.first { $0.id == sceneID }?.guides.count ?? 1) - 1
    }

    public func moveGuide(at index: Int, to position: Double, sceneID: String, coalesceKey: String?,
                          in engine: inout CommandEngine) throws {
        try engine.perform(MoveGuide(sceneID: sceneID, index: index, position: position), coalesceKey: coalesceKey)
    }

    public func removeGuide(at index: Int, sceneID: String, in engine: inout CommandEngine) throws {
        try engine.perform(RemoveGuide(sceneID: sceneID, index: index))
    }
}
