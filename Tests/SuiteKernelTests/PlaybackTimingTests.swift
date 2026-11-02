// PlaybackTimingTests.swift: the suite's playback clock (#5077), SuiteKernel's Playback module. The ticker turns
// display-link targets into elapsed seconds (the first tick only sets the baseline, a pause never counts); the
// timing maps seconds onto the frame shown at the exact rate, with once, loop and ping-pong. `Player` drives both the
// way Flare and Halo do: elapsed seconds from an anchor frame, re-anchored on a scrub and a pause. Linux and macOS.
import SuiteKernel
import Testing

private let fps24 = FrameRate(whole: 24)
private let ntsc23 = FrameRate(numerator: 24000, denominator: 1001)
private let ntsc29 = FrameRate(numerator: 30000, denominator: 1001)

/// A player as the apps build one: an anchor frame and the seconds played since it, fed by a ticker.
private struct Player {
    var rate = fps24, frames = 48, mode = PlaybackMode.loop
    var ticker = PlaybackTicker(), start = 0, played = 0.0
    private(set) var frame = 0, ended = false

    mutating func tick(_ target: Double) {
        if let elapsed = ticker.elapsed(toTarget: target) { played += elapsed }
        let t = PlaybackTiming.tick(startFrame: start, elapsed: played, rate: rate, durationFrames: frames, mode: mode)
        (frame, ended) = (t.frame, t.ended)
    }

    /// Feeds every target and returns each distinct frame shown, in order, starting with the first.
    mutating func run(_ targets: [Double]) -> [Int] {
        var shown = [frame]
        for target in targets {
            tick(target)
            if shown.last != frame { shown.append(frame) }
        }
        return shown
    }

    mutating func scrub(to f: Int) { (start, played, frame) = (f, 0, f) }
    mutating func pause() { ticker.reset(); (start, played) = (frame, 0) }
}

/// `seconds` of `hz` targets from `origin`, far from zero like the link's media clock.
private func targets(seconds: Double, hz: Double, origin: Double = 7000) -> [Double] {
    (0...Int((seconds * hz).rounded())).map { origin + Double($0) / hz }
}

private func tick(_ start: Int, _ elapsed: Double, rate: FrameRate = fps24, n: Int = 48, _ mode: PlaybackMode)
    -> PlaybackTick {
    PlaybackTiming.tick(startFrame: start, elapsed: elapsed, rate: rate, durationFrames: n, mode: mode)
}

@Suite struct PlaybackTimingTests {
    @Test func theFirstTickOnlySetsTheBaseline() {
        var ticker = PlaybackTicker()
        #expect(ticker.elapsed(toTarget: 5000) == nil && ticker.lastTarget == 5000)
        #expect(ticker.elapsed(toTarget: 5000.25) == 0.25)
        ticker.reset()
        #expect(ticker.lastTarget == nil && ticker.elapsed(toTarget: 6000) == nil)
    }

    @Test func lateOrBrokenTargetsAreIgnored() {
        var ticker = PlaybackTicker()
        #expect(ticker.elapsed(toTarget: 1) == nil)
        for bad in [0.5, 1, .nan, .infinity, -.infinity] { #expect(ticker.elapsed(toTarget: bad) == nil) }
        #expect(ticker.lastTarget == 1)
        #expect(ticker.elapsed(toTarget: 1.25) == 0.25)
    }

    /// QB-L4: 5 s of 60 Hz ticks at 24 fps shows every frame in order, none skipped, and lands on the clock's frame.
    @Test func fiveSecondsAt60HzShowsEveryFrameWithoutDrift() {
        var player = Player()
        #expect(player.run(targets(seconds: 5, hz: 60)) == (0...120).map { $0 % 48 })
        #expect(player.frame == 24 && abs(player.played - 5) < 1e-9)
    }

    /// 1001 s at 23.976 is exactly 24000 frames: an hour-scale run at 60 Hz neither drifts nor drops a frame.
    @Test func aLongRunAt23976NeverDrifts() {
        var player = Player(rate: ntsc23, frames: 100_000, mode: .once)
        let shown = player.run(targets(seconds: 1001, hz: 60))
        #expect(player.frame == 24000 && !player.ended)
        #expect(shown == Array(0...24000))
    }

    @Test func fractionalRatesCountTheExactRate() {
        #expect(tick(0, 10.01, rate: ntsc29, n: 1000, .once).frame == 300)
        #expect(tick(0, 1001, rate: ntsc23, n: 100_000, .once).frame == 24000)
        // A 23.976 frame lasts 1001/24000 s: a hair before it is frame 0, the edge itself is frame 1.
        #expect(tick(0, 1001.0 / 24000 - 1e-6, rate: ntsc23, .loop).frame == 0)
        #expect(tick(0, 1001.0 / 24000, rate: ntsc23, .loop).frame == 1)
        // A late start counts from its own frame's time: frame 300 at 29.97 plus one frame is 301.
        #expect(tick(300, 1001.0 / 30000, rate: ntsc29, n: 1000, .once).frame == 301)
    }

    @Test func loopWrapsToTheFirstFrame() {
        #expect(tick(0, 2.0, .loop) == PlaybackTick(frame: 0, ended: false))
        #expect(tick(0, 2.5, .loop) == PlaybackTick(frame: 12, ended: false))
        #expect(tick(40, 0.5, .loop) == PlaybackTick(frame: 4, ended: false))
        #expect(tick(47, 1.0 / 24, .loop) == PlaybackTick(frame: 0, ended: false))
    }

    @Test func onceEndsAfterTheLastFrameHasHadItsTime() {
        #expect(tick(0, 1.99, .once) == PlaybackTick(frame: 47, ended: false))
        #expect(tick(0, 2.0, .once) == PlaybackTick(frame: 47, ended: true))
        #expect(tick(40, 1.0, .once) == PlaybackTick(frame: 47, ended: true))
        #expect(tick(0, 1e300, .once) == PlaybackTick(frame: 47, ended: true))
    }

    @Test func pingPongRunsForwardThenBackAndNeverEnds() {
        let frames = (0..<10).map { tick(0, Double($0), rate: FrameRate(whole: 1), n: 4, .pingPong) }
        #expect(frames.map(\.frame) == [0, 1, 2, 3, 2, 1, 0, 1, 2, 3])
        #expect(frames.allSatisfy { !$0.ended })
        #expect(tick(2, 2.0, rate: FrameRate(whole: 1), n: 4, .pingPong).frame == 2)
        #expect(tick(0, 5, rate: FrameRate(whole: 1), n: 1, .pingPong) == PlaybackTick(frame: 0, ended: false))
        #expect(tick(0, 1e300, n: .max, .pingPong).frame == Int.max - 1)
    }

    @Test func noTimeHoldsTheStartFrame() {
        for mode in PlaybackMode.allCases {
            for elapsed in [Double.nan, .infinity, -1, 0] {
                #expect(tick(7, elapsed, mode) == PlaybackTick(frame: 7, ended: false))
            }
            #expect(tick(99, 0, mode).frame == 47)
            #expect(tick(7, 1, rate: FrameRate(whole: 0), mode) == PlaybackTick(frame: 0, ended: false))
            #expect(tick(7, 1, n: 0, mode) == PlaybackTick(frame: 0, ended: false))
        }
    }

    /// A refresh that comes late lands straight on the clock's frame: the frames between count as dropped.
    @Test func aStallCatchesUpToTheClock() {
        var player = Player()
        let shown = player.run([7000, 7000 + 1.0 / 24, 7000 + 2.0 / 24, 7000 + 6.0 / 24, 7000 + 7.0 / 24])
        #expect(shown == [0, 1, 2, 6, 7])
        #expect(PlaybackBudget.droppedFrames(in: shown, timelineFrames: 48) == 3)
    }

    @Test func aScrubWhilePlayingContinuesFromTheScrub() {
        var player = Player()
        _ = player.run([7000, 7000 + 10.0 / 24])
        #expect(player.frame == 10)
        player.scrub(to: 40)
        player.tick(7000 + 11.0 / 24)
        #expect(player.frame == 41)
        player.tick(7000 + 19.0 / 24)
        #expect(player.frame == 1)
    }

    /// A pause holds the frame it stopped on; the paused time never counts, and play resumes on that exact frame.
    @Test func aPauseStopsOnTheExactFrame() {
        var player = Player()
        _ = player.run([7000, 7000.5])
        #expect(player.frame == 12)
        player.pause()
        player.tick(7010)
        #expect(player.frame == 12)
        player.tick(7010 + 1.0 / 24)
        #expect(player.frame == 13)
    }

    @Test func droppedFramesCountForwardStepsAcrossTheLoop() {
        #expect(PlaybackBudget.droppedFrames(in: [46, 47, 0, 1, 1], timelineFrames: 48) == 0)
        #expect(PlaybackBudget.droppedFrames(in: [0, 3], timelineFrames: 48) == 2)
        #expect(PlaybackBudget.droppedFrames(in: [47, 1], timelineFrames: 48) == 1)
        #expect(PlaybackBudget.droppedFrames(in: [5], timelineFrames: 48) == 0)
        #expect(PlaybackBudget.droppedFrames(in: [0, 3], timelineFrames: 0) == 0)
    }
}
