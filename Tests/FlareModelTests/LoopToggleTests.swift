// LoopToggleTests.swift: turning Loop off while a looping scene plays keeps the playhead where it is and keeps
// playing to the scene's last frame (#614).
import FlareCore
@testable import FlareModel
import Testing

/// A 48-frame scene at 24 fps: one pass is 2 s.
private let document = Document(
    scenes: [Scene(id: "scene-1", name: "Scene 1", fps: 24, durationFrames: 48, layers: [Layer(id: "a", name: "A")])]
)

@Test func turningLoopOffPastTheFirstPassPlaysOnFromThePlayheadToTheLastFrame() {
    var w = FlareWorkspace(services: .fake())
    w.load(document)
    w.play()
    w.advance(elapsed: 2.5)
    #expect(w.currentFrame == 12 && w.isPlaying)
    w.setLoops(false)
    #expect(w.currentFrame == 12 && w.isPlaying)
    w.advance(elapsed: 0.5)
    #expect(w.currentFrame == 24 && w.isPlaying)
    w.advance(elapsed: 0.9375)
    #expect(w.currentFrame == 46 && w.isPlaying)
    w.advance(elapsed: 0.0625)
    #expect(w.currentFrame == 47 && !w.isPlaying)
}

@Test func turningLoopBackOnKeepsThePlayheadToo() {
    var w = FlareWorkspace(services: .fake())
    w.load(document)
    w.setLoops(false)
    w.play()
    w.advance(elapsed: 1.5)
    w.setLoops(true)
    w.advance(elapsed: 0.25)
    #expect(w.currentFrame == 42 && w.isPlaying)
    w.advance(elapsed: 0.5)
    #expect(w.currentFrame == 6 && w.isPlaying)
}
