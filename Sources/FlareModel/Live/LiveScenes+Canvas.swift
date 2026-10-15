// LiveScenes+Canvas.swift: the live scene editor, canvas and timing (docs/blueprints/flare/features/live-scenes.md,
// task SN-3). `setCanvas` is FlareCore's `SetSceneCanvas` wrapped in `engine.group("Set Canvas")`, so the undo
// name is the fake's; `setTiming` is `SetSceneTiming` ("Set Scene Timing"), as `FakeScenes` does. A size, fps or
// length the engine refuses throws and leaves no change and no undo entry. `setCanvas` refuses an unknown scene, a
// bad size or a non-finite background before `group` runs, because `group` ends the current coalesce run (a guide
// drag) even when its body throws; a refused write must leave no trace, as the fake's does.
import FlareCore

extension LiveScenes {
    public func setCanvas(_ id: String, width: Double, height: Double, background: FlareColor,
                          in engine: inout CommandEngine) throws {
        guard engine.document.scenes.contains(where: { $0.id == id }) else { throw CommandError.sceneNotFound(id) }
        guard width.isFinite, width > 0, height.isFinite, height > 0 else {
            throw CommandError.invalidDocument("scene \(id): canvas size must be finite and > 0")
        }
        guard background.isFinite else {
            throw CommandError.invalidDocument("scene \(id): background color channels must be finite")
        }
        try engine.group("Set Canvas") {
            try $0.perform(SetSceneCanvas(sceneID: id, width: width, height: height, background: background))
        }
    }

    public func setTiming(_ id: String, fps: Int, durationFrames: Int, in engine: inout CommandEngine) throws {
        try engine.perform(SetSceneTiming(sceneID: id, fps: fps, durationFrames: durationFrames))
    }
}
