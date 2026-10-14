// FlarePlaybackTests.swift: LM-7 playback state (docs/blueprints/flare.md, 7.5). The acceptance test: 2.5 s at
// 24 fps looping lands on 12; without loop it stops on the last frame; inside a 12-frame symbol it loops 0–11.
// Also the model half of the playback budgets: QB-L4 (no frame skipped or repeated at the document rate, cheap
// ticks, no drift) and QB-F3 (playback and scrubbing are not undo steps).
import FlareCore
@testable import FlareModel
import Testing

/// A 48-frame scene at 24 fps that places a 12-frame symbol.
private let document = Document(
    scenes: [Scene(id: "scene-1", name: "Scene 1", fps: 24, durationFrames: 48, layers: [Layer(id: "a", name: "A")])],
    symbols: [Symbol(id: "tick", name: "Tick", durationFrames: 12, layers: [Layer(id: "t", name: "T")])]
)

private func workspace(_ document: Document = document) -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(document)
    return w
}

@Test func twoAndAHalfSecondsAt24FpsLoopingLandsOn12() {
    var w = workspace()
    w.play()
    w.advance(elapsed: 2.5)
    #expect(w.currentFrame == 12 && w.isPlaying && w.loops)
}

@Test func withoutLoopPlaybackStopsOnTheLastFrame() {
    var w = workspace()
    w.setLoops(false)
    w.play()
    w.advance(elapsed: 1.99)
    #expect(w.currentFrame == 47 && w.isPlaying)
    w.advance(elapsed: 0.51)
    #expect(w.currentFrame == 47 && !w.isPlaying)
    w.advance(elapsed: 1)
    #expect(w.currentFrame == 47)
    w.play()
    #expect(w.currentFrame == 0 && w.isPlaying)
}

@Test func insideA12FrameSymbolPlaybackLoops0To11() {
    var w = workspace()
    w.editSymbol("tick")
    #expect(w.playbackRange == 0..<12 && w.playbackFPS == 24)
    w.play()
    var seen: [Int] = []
    for _ in 0..<24 { w.advance(elapsed: 1.0 / 24); seen.append(w.currentFrame) }
    #expect(seen == Array(1...11) + [0] + Array(1...11) + [0])
    w.setCurrentFrame(40)
    #expect(w.currentFrame == 11)
    w.exitSymbol()
    #expect(w.playbackRange == 0..<48 && !w.isPlaying)
}

@Test func playStartsFromThePlayheadAndPauseHoldsIt() {
    var w = workspace()
    w.setCurrentFrame(30)
    w.togglePlay()
    w.advance(elapsed: 0.5)
    #expect(w.currentFrame == 42)
    w.togglePlay()
    w.advance(elapsed: 1)
    #expect(w.currentFrame == 42 && !w.isPlaying)
    w.setCurrentFrame(-5)
    #expect(w.currentFrame == 0)
}

@Test func scrubbingWhilePlayingContinuesFromTheNewFrame() {
    var w = workspace()
    w.play()
    w.advance(elapsed: 0.25)
    w.setCurrentFrame(20)
    w.advance(elapsed: 0.25)
    #expect(w.currentFrame == 26 && w.isPlaying)
}

@Test func stepWrapsWithLoopAndClampsWithout() {
    var w = workspace()
    w.play()
    w.goToEnd()
    w.stepFrame(by: 2)
    #expect(w.currentFrame == 1 && !w.isPlaying)
    w.stepFrame(by: -3)
    #expect(w.currentFrame == 46)
    w.setLoops(false)
    w.stepFrame(by: 5)
    #expect(w.currentFrame == 47)
    w.goToStart()
    w.stepFrame(by: -1)
    #expect(w.currentFrame == 0)
    w.stepFrame(by: Int.max)
    #expect(w.currentFrame == 47)
}

@Test func readoutsShowTheFrameAndTheTimecode() {
    var w = workspace()
    w.setCurrentFrame(12)
    #expect(w.frameReadout == "12 / 48" && w.timecode == "00:12 / 02:00")
    w.editSymbol("tick")
    #expect(w.frameReadout == "0 / 12" && w.timecode == "00:00 / 00:12")
}

@Test func noTimelineMeansNoPlayback() {
    var w = FlareWorkspace(services: .fake())
    #expect(!w.canPlay && w.frameReadout == nil && w.timecode == nil)
    w.play()
    w.advance(elapsed: 1)
    w.stepFrame(by: 1)
    #expect(!w.isPlaying && w.currentFrame == 0)
    var empty = workspace(Document(scenes: [Scene(id: "s", name: "S", durationFrames: 0)]))
    empty.play()
    #expect(!empty.isPlaying)
}

@Test func badElapsedTimesAreIgnored() {
    var w = workspace()
    w.play()
    for bad in [-1, 0, .nan, .infinity] { w.advance(elapsed: bad) }
    #expect(w.currentFrame == 0 && w.playClock == 0 && w.isPlaying)
}

/// QB-L4, model half: 5 s of 60 Hz ticks at 24 fps shows every frame in order, none skipped or repeated past its
/// time, and lands exactly where the clock says. The ticks together take a sliver of one refresh each (a total, so
/// one preempted tick on a shared machine does not fail it alone).
@Test func fiveSecondsAt60HzTicksShowsEveryFrameWithoutDrift() {
    var w = workspace()
    w.play()
    var shown: [Int] = [0]
    let clock = ContinuousClock()
    var total = Duration.zero
    for _ in 0..<300 {
        total += clock.measure { w.advance(elapsed: 1.0 / 60) }
        if shown.last != w.currentFrame { shown.append(w.currentFrame) }
    }
    let expected = (0...120).map { $0 % 48 }
    #expect(shown == expected)
    #expect(w.currentFrame == 24 && abs(w.playClock - 5) < 1e-9)
    #expect(total < .milliseconds(150))
}

/// QB-F3: playback and scrubbing are not undo steps and leave the document as it was.
@Test func playbackAndScrubbingAreNotUndoSteps() {
    var w = workspace()
    w.play()
    for _ in 0..<100 { w.advance(elapsed: 0.05) }
    w.setCurrentFrame(10); w.stepFrame(by: 3); w.goToEnd(); w.setLoops(false)
    #expect(!w.canUndo && w.document == document)
}
