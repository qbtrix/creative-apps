// LoopOffOnWrapTests.swift: turning Loop off on the tick the playhead wraps to frame 0 keeps it there and plays the
// whole pass to the last frame, even when summed display-link ticks leave the clock a hair under a pass (#653).
import FlareCore
@testable import FlareModel
import Testing

@Test func turningLoopOffOnTheWrapTickPlaysTheWholePassFromFrameZero() {
    let doc = Document(
        scenes: [Scene(id: "s", name: "S", fps: 24, durationFrames: 48, layers: [Layer(id: "a", name: "A")])]
    )
    var w = FlareWorkspace(services: .fake())
    w.load(doc)
    w.play()
    for _ in 0..<120 { w.advance(elapsed: 1.0 / 60) }
    #expect(w.currentFrame == 0 && w.isPlaying)
    w.setLoops(false)
    #expect(w.currentFrame == 0 && w.isPlaying)
    w.advance(elapsed: 1.0 / 60)
    #expect(w.currentFrame == 0 && w.isPlaying)
    w.advance(elapsed: 1.9)
    #expect(w.currentFrame == 46 && w.isPlaying)
    w.advance(elapsed: 0.1)
    #expect(w.currentFrame == 47 && !w.isPlaying)
}

/// The issue's sweep: 60 Hz and 120 Hz ticks over several rates and lengths, turning Loop off on every tick of the
/// third pass. The playhead never moves back or jumps more than one tick's worth of frames, and play runs to the end.
@Test(arguments: [(24, 48), (30, 90), (12, 7), (25, 100)], [60.0, 120.0])
func turningLoopOffOnAnyTickNeverJumpsThePlayhead(scene: (fps: Int, frames: Int), hz: Double) {
    let doc = Document(
        scenes: [Scene(id: "s", name: "S", fps: scene.fps, durationFrames: scene.frames, layers: [Layer(id: "a", name: "A")])]
    )
    let ticksPerPass = Int((Double(scene.frames) / Double(scene.fps) * hz).rounded(.up))
    for offTick in (2 * ticksPerPass)..<(3 * ticksPerPass) {
        var w = FlareWorkspace(services: .fake())
        w.load(doc)
        w.play()
        for _ in 0..<offTick { w.advance(elapsed: 1 / hz) }
        let before = w.currentFrame
        w.setLoops(false)
        #expect(w.currentFrame == before && w.isPlaying)
        w.advance(elapsed: 1 / hz)
        let step = w.currentFrame - before
        #expect(step >= 0 && step <= 1 + Int(Double(scene.fps) / hz), "fps \(scene.fps) tick \(offTick): \(before) → \(w.currentFrame)")
        var guardTicks = 0
        while w.isPlaying, guardTicks < ticksPerPass + 2 { w.advance(elapsed: 1 / hz); guardTicks += 1 }
        #expect(!w.isPlaying && w.currentFrame == scene.frames - 1)
    }
}
