// PlayheadClampTests.swift: the playhead never stands past the timeline's end (#615). Switching to a shorter scene
// or shortening the scene, by the inspector or by undo and redo, clamps it to the last frame, like `exitSymbol`.
import FlareCore
@testable import FlareModel
import Testing

private let document = Document(scenes: [
    Scene(id: "long", name: "Long", fps: 24, durationFrames: 48, layers: [Layer(id: "a", name: "A")]),
    Scene(id: "short", name: "Short", fps: 24, durationFrames: 12, layers: [Layer(id: "b", name: "B")]),
])

private func workspaceOnFrame40() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(document)
    w.setCurrentFrame(40)
    return w
}

@Test func selectingAShorterSceneClampsThePlayheadToItsLastFrame() {
    var w = workspaceOnFrame40()
    w.selectScene("short")
    #expect(w.playbackRange.contains(w.currentFrame))
    #expect(w.currentFrame == 11 && w.frameReadout == "11 / 12" && w.timecode == "00:11 / 00:12")
    // Back to the longer scene the playhead stays where it is.
    w.selectScene("long")
    #expect(w.currentFrame == 11)
}

@Test func selectingASceneStopsPlayback() {
    var w = workspaceOnFrame40()
    w.play()
    w.selectScene("short")
    #expect(!w.isPlaying && w.currentFrame == 11)
    w.play()
    w.advance(elapsed: 1.0 / 24)
    #expect(w.currentFrame == 0 && w.isPlaying)
}

@Test func shorteningTheSceneClampsThePlayheadAndUndoRedoKeepItInRange() {
    var w = workspaceOnFrame40()
    w.setSceneTiming(fps: 24, durationFrames: 12)
    #expect(w.layerError == nil && w.currentFrame == 11 && w.frameReadout == "11 / 12")
    w.undo()
    #expect(w.timelineFrames == 48 && w.currentFrame == 11)
    w.setCurrentFrame(40)
    w.redo()
    #expect(w.timelineFrames == 12 && w.currentFrame == 11)
}

@Test func lengtheningTheSceneLeavesThePlayhead() {
    var w = workspaceOnFrame40()
    w.setSceneTiming(fps: 24, durationFrames: 96)
    #expect(w.currentFrame == 40)
}

@Test func shorteningTheSceneWhilePlayingKeepsTheClockOnTheClampedFrame() {
    var w = workspaceOnFrame40()
    w.play()
    w.setSceneTiming(fps: 24, durationFrames: 12)
    #expect(w.currentFrame == 11 && w.isPlaying)
    w.advance(elapsed: 1.0 / 24)
    #expect(w.currentFrame == 0)
}

@Test func anEmptySceneLeavesThePlayheadOnFrameZero() {
    var w = workspaceOnFrame40()
    w.setSceneTiming(fps: 24, durationFrames: 0)
    #expect(w.currentFrame == 0 && w.frameReadout == nil)
}
