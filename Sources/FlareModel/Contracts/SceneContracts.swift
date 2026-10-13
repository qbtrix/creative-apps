// SceneContracts.swift: scenes, canvas, timing and guides (docs/blueprints/flare.md,
// section 6.2). Each write names its undo case from section 2.
import FlareCore

public protocol SceneEditing: Sendable {
    func newDocument(_ preset: CanvasPreset) -> Document
    /// Single. Returns the new scene's id.
    func addScene(_ preset: CanvasPreset, in engine: inout CommandEngine) throws -> String
    /// Single.
    func renameScene(_ id: String, to name: String, in engine: inout CommandEngine) throws
    /// Single. Throws when it is the last scene.
    func removeScene(_ id: String, in engine: inout CommandEngine) throws
    /// Single.
    func reorderScene(_ id: String, to index: Int, in engine: inout CommandEngine) throws
    /// Single.
    func setCanvas(_ id: String, width: Double, height: Double, background: FlareColor,
                   in engine: inout CommandEngine) throws
    /// Single.
    func setTiming(_ id: String, fps: Int, durationFrames: Int, in engine: inout CommandEngine) throws
    /// Single. Returns the new guide's index.
    func addGuide(_ axis: Guide.Axis, at position: Double, sceneID: String,
                  in engine: inout CommandEngine) throws -> Int
    /// Coalescible (LC-10 merges `MoveGuide`).
    func moveGuide(at index: Int, to position: Double, sceneID: String, coalesceKey: String?,
                   in engine: inout CommandEngine) throws
    /// Single.
    func removeGuide(at index: Int, sceneID: String, in engine: inout CommandEngine) throws
}
