// PlaybackRateChangeTests.swift: changing the scene's frame rate while playing keeps the playhead on its frame and
// plays on from there at the new rate (#640), by the inspector or by undo and redo.
import FlareCore
@testable import FlareModel
import Testing

private let document = Document(scenes: [
    Scene(id: "long", name: "Long", fps: 24, durationFrames: 48, layers: [Layer(id: "a", name: "A")]),
])

private func playingOnFrame20() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(document)
    w.setCurrentFrame(20)
    w.play()
    return w
}

@Test func slowingTheRateWhilePlayingKeepsThePlayheadOnItsFrame() {
    var w = playingOnFrame20()
    w.setSceneTiming(fps: 12, durationFrames: 48)
    w.advance(elapsed: 0.001)
    #expect(w.currentFrame == 20 && w.isPlaying)
    // One frame's time at the new rate moves it one frame.
    w.advance(elapsed: 1.0 / 12)
    #expect(w.currentFrame == 21)
}

@Test func speedingUpTheRateWhilePlayingKeepsThePlayheadOnItsFrame() {
    var w = playingOnFrame20()
    w.setSceneTiming(fps: 48, durationFrames: 48)
    w.advance(elapsed: 0.001)
    #expect(w.currentFrame == 20 && w.isPlaying)
}

@Test func undoingARateChangeWhilePlayingKeepsThePlayheadOnItsFrame() {
    var w = playingOnFrame20()
    w.setSceneTiming(fps: 12, durationFrames: 48)
    w.undo()
    w.advance(elapsed: 0.001)
    #expect(w.currentFrame == 20)
    w.redo()
    w.advance(elapsed: 0.001)
    #expect(w.currentFrame == 20 && w.isPlaying)
}

@Test func aRateChangeWhilePausedLeavesThePlayheadAlone() {
    var w = playingOnFrame20()
    w.pause()
    w.setSceneTiming(fps: 12, durationFrames: 48)
    #expect(w.currentFrame == 20 && !w.isPlaying)
}
