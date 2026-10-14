// PlaybackLengthChangeTests.swift: changing the scene's duration during a looping play past its first pass keeps the
// playhead on its frame, clamped to the new last frame, and plays on from there (#665), by the inspector or by undo.
import FlareCore
@testable import FlareModel
import Testing

private let document = Document(scenes: [
    Scene(id: "long", name: "Long", fps: 24, durationFrames: 48, layers: [Layer(id: "a", name: "A")]),
])

/// A looping play on its second pass, standing on frame 20.
private func loopingOnSecondPassFrame20() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(document)
    w.setLoops(true)
    w.play()
    w.advance(elapsed: 68.0 / 24 + 0.001)
    return w
}

@Test func lengtheningTheSceneOnALaterPassKeepsThePlayheadOnItsFrame() {
    var w = loopingOnSecondPassFrame20()
    #expect(w.currentFrame == 20)
    w.setSceneTiming(fps: 24, durationFrames: 60)
    w.advance(elapsed: 0.001)
    #expect(w.currentFrame == 20 && w.isPlaying)
    // One frame's time moves it one frame.
    w.advance(elapsed: 1.0 / 24)
    #expect(w.currentFrame == 21)
}

@Test func shorteningTheSceneOnALaterPassKeepsAnInRangePlayheadOnItsFrame() {
    var w = loopingOnSecondPassFrame20()
    w.setSceneTiming(fps: 24, durationFrames: 30)
    w.advance(elapsed: 0.001)
    #expect(w.currentFrame == 20 && w.isPlaying)
}

@Test func shorteningTheScenePastThePlayheadOnALaterPassPlaysOnFromTheNewLastFrame() {
    var w = loopingOnSecondPassFrame20()
    w.setSceneTiming(fps: 24, durationFrames: 12)
    #expect(w.currentFrame == 11)
    w.advance(elapsed: 0.001)
    #expect(w.currentFrame == 11 && w.isPlaying)
    // The last frame's time wraps to the first.
    w.advance(elapsed: 1.0 / 24)
    #expect(w.currentFrame == 0)
}

@Test func undoingALengthChangeOnALaterPassKeepsThePlayheadOnItsFrame() {
    var w = loopingOnSecondPassFrame20()
    w.setSceneTiming(fps: 24, durationFrames: 60)
    w.advance(elapsed: 3.0 / 24)
    #expect(w.currentFrame == 23)
    w.undo()
    w.advance(elapsed: 0.001)
    #expect(w.currentFrame == 23 && w.isPlaying)
}
