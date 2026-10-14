// FlarePlaybackTicksTests.swift: LA-2's platform-neutral core (docs/blueprints/flare.md, 7.5). A fake tick source
// (a list of display-link target timestamps) drives FlareWorkspace.tick the way PlaybackDriver does on macOS. The
// acceptance test: it stops when paused and uses the link's target timestamp, not wall time. Also QB-L4's CI gate:
// 5 s at the document rate drops at most 2 frames.
import FlareCore
@testable import FlareModel
import Testing

/// A 48-frame scene at 24 fps.
private let document = Document(
    scenes: [Scene(id: "scene-1", name: "Scene 1", fps: 24, durationFrames: 48, layers: [Layer(id: "a", name: "A")])]
)

private func workspace() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(document)
    return w
}

/// The fake tick source: `count` targets at `hz` from `start`, each off its slot by up to `jitter` seconds.
private func targets(start: Double = 1000, hz: Double, count: Int, jitter: Double = 0) -> [Double] {
    let pattern: [Double] = [0, 1, -0.5, 0.25, -1, 0.75, -0.25]
    return (0..<count).map { i in
        let offset = jitter * pattern[i % pattern.count]
        return start + Double(i) / hz + offset
    }
}

/// Feeds every target to the workspace, as the driver does; stops at the first tick that returns false.
/// Returns the playhead after each tick.
private func run(_ w: inout FlareWorkspace, _ ticker: inout PlaybackTicker, _ targets: [Double]) -> [Int] {
    var frames: [Int] = []
    for target in targets {
        let running = w.tick(target: target, ticker: &ticker)
        frames.append(w.currentFrame)
        if !running { break }
    }
    return frames
}

@Test func theFirstTickOnlySetsTheBaseline() {
    var (w, ticker) = (workspace(), PlaybackTicker())
    w.play()
    #expect(w.tick(target: 5000, ticker: &ticker))
    #expect(w.currentFrame == 0 && ticker.lastTarget == 5000)
    #expect(w.tick(target: 5000 + 1.0 / 24, ticker: &ticker))
    #expect(w.currentFrame == 1)
}

@Test func playbackFollowsTheTargetTimestampsNotWallTime() {
    var (w, ticker) = (workspace(), PlaybackTicker())
    w.play()
    // Two ticks 2.5 s apart on the link's clock land on frame 12, however long the calls took.
    _ = run(&w, &ticker, [10, 12.5])
    #expect(w.currentFrame == 12 && w.isPlaying)
}

@Test func pausedTicksMoveNothingAndStopTheDriver() {
    var (w, ticker) = (workspace(), PlaybackTicker())
    w.play()
    _ = run(&w, &ticker, [0, 0.5])
    #expect(w.currentFrame == 12)
    w.pause()
    #expect(!w.tick(target: 1, ticker: &ticker))
    #expect(w.currentFrame == 12 && ticker.lastTarget == nil)
    // Ten seconds later play resumes: the pause is not counted as play time.
    w.play()
    #expect(w.tick(target: 11, ticker: &ticker))
    #expect(w.currentFrame == 12)
    #expect(w.tick(target: 11 + 1.0 / 24, ticker: &ticker))
    #expect(w.currentFrame == 13)
}

@Test func withoutLoopTheLastTickStopsTheDriver() {
    var (w, ticker) = (workspace(), PlaybackTicker())
    w.setLoops(false)
    w.play()
    let frames = run(&w, &ticker, targets(hz: 60, count: 300))
    #expect(frames.last == 47 && !w.isPlaying && ticker.lastTarget == nil)
    #expect(frames.count < 300)
}

@Test func lateOrBrokenTargetsAreIgnored() {
    var ticker = PlaybackTicker()
    #expect(ticker.elapsed(toTarget: 1) == nil)
    #expect(ticker.elapsed(toTarget: 0.5) == nil)
    #expect(ticker.elapsed(toTarget: 1) == nil)
    #expect(ticker.elapsed(toTarget: .nan) == nil)
    #expect(ticker.elapsed(toTarget: .infinity) == nil)
    #expect(ticker.lastTarget == 1)
    #expect(ticker.elapsed(toTarget: 1.25) == 0.25)
}

@Test(arguments: [60.0, 120.0])
func fiveSecondsAtTheDocumentRateDropNoFrames(hz: Double) {
    var (w, ticker) = (workspace(), PlaybackTicker())
    w.play()
    let frames = run(&w, &ticker, targets(hz: hz, count: Int(PlaybackBudget.seconds * hz) + 1, jitter: 0.001))
    let dropped = PlaybackBudget.droppedFrames(in: frames, timelineFrames: 48)
    #expect(dropped == 0)
    #expect(dropped <= PlaybackBudget.ciMaxDroppedFrames)
    // 5 s at 24 fps: about 120 frames (the last target's jitter can land it one short), 2.5 passes of the loop.
    #expect((119 % 48...120 % 48).contains(w.currentFrame) && w.isPlaying)
}

@Test func oneStallStaysInsideTheCIGate() {
    var (w, ticker) = (workspace(), PlaybackTicker())
    w.play()
    // A 100 ms hitch on a shared machine halfway through the 5 s run.
    let ticks = targets(hz: 60, count: 301).map { $0 >= 1002.5 ? $0 + 0.1 : $0 }
    let dropped = PlaybackBudget.droppedFrames(in: run(&w, &ticker, ticks), timelineFrames: 48)
    #expect(dropped > 0 && dropped <= PlaybackBudget.ciMaxDroppedFrames)
}

@Test func droppedFramesCountForwardStepsAcrossTheLoop() {
    #expect(PlaybackBudget.droppedFrames(in: [46, 47, 0, 1, 1], timelineFrames: 48) == 0)
    #expect(PlaybackBudget.droppedFrames(in: [0, 3], timelineFrames: 48) == 2)
    #expect(PlaybackBudget.droppedFrames(in: [47, 1], timelineFrames: 48) == 1)
    #expect(PlaybackBudget.droppedFrames(in: [5], timelineFrames: 48) == 0)
    #expect(PlaybackBudget.droppedFrames(in: [0, 3], timelineFrames: 0) == 0)
}
