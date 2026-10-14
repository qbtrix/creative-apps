// LiveScenes+Canvas.swift: the live scene editor, canvas and timing (docs/blueprints/flare/features/live-scenes.md,
// task SN-3). `setCanvas` is FlareCore's `SetSceneCanvas` wrapped in `engine.group("Set Canvas")`, so the undo
// name is the fake's; `setTiming` is `SetSceneTiming` ("Set Scene Timing"), as `FakeScenes` does. A size, fps or
// length the engine refuses throws and leaves no change and no undo entry.
import FlareCore

extension LiveScenes {
    public func setCanvas(_ id: String, width: Double, height: Double, background: FlareColor,
                          in engine: inout CommandEngine) throws {
        try engine.group("Set Canvas") {
            try $0.perform(SetSceneCanvas(sceneID: id, width: width, height: height, background: background))
        }
    }

    public func setTiming(_ id: String, fps: Int, durationFrames: Int, in engine: inout CommandEngine) throws {
        try engine.perform(SetSceneTiming(sceneID: id, fps: fps, durationFrames: durationFrames))
    }
}
