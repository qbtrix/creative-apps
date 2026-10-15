// PlaybackClockContractTests.swift: what every PlaybackClock promises (#37),
// run over each conforming type in `playbackClocks`: the fake and the live
// type, so the two must agree. The edges match FlareCore's playbackFrame.
// Runs on Linux and macOS.
import HaloModel
import Testing

let playbackClocks: [any PlaybackClock] = [FakePlaybackClock(), LivePlaybackClock()]

/// VP-2's rows: 24 fps, 72 frames.
private func tick(_ clock: any PlaybackClock, _ start: Int, _ elapsed: Double, n: Int = 72, loops: Bool)
    -> HaloPlaybackTick {
    clock.tick(startFrame: start, elapsed: elapsed, framesPerSecond: 24, durationFrames: n, loops: loops)
}

@Test(arguments: playbackClocks)
func clockAdvancesAtTheFrameRate(clock: any PlaybackClock) {
    #expect(tick(clock, 0, 1.0, loops: true) == HaloPlaybackTick(frame: 24, ended: false))
    #expect(tick(clock, 0, 1.0, loops: false) == HaloPlaybackTick(frame: 24, ended: false))
    #expect(tick(clock, 0, 1.0 / 24, loops: true) == HaloPlaybackTick(frame: 1, ended: false))
    #expect(tick(clock, 60, 1.0 / 24, loops: true) == HaloPlaybackTick(frame: 61, ended: false))
}

@Test(arguments: playbackClocks)
func clockLoopsFromALateStart(clock: any PlaybackClock) {
    #expect(tick(clock, 60, 1.0, loops: true) == HaloPlaybackTick(frame: 12, ended: false))
}

@Test(arguments: playbackClocks)
func clockPlayOnceEndsOnTheLastFrameFromALateStart(clock: any PlaybackClock) {
    #expect(tick(clock, 60, 1.0, loops: false) == HaloPlaybackTick(frame: 71, ended: true))
}

@Test(arguments: playbackClocks)
func clockHoldsTheStartForNoTime(clock: any PlaybackClock) {
    for elapsed in [Double.nan, -1] {
        #expect(tick(clock, 60, elapsed, loops: true) == HaloPlaybackTick(frame: 60, ended: false))
        #expect(tick(clock, 60, elapsed, loops: false) == HaloPlaybackTick(frame: 60, ended: false))
    }
    #expect(tick(clock, 60, 1.0, n: 0, loops: true) == HaloPlaybackTick(frame: 0, ended: false))
}

@Test func liveClockIsAvailable() {
    #expect(LivePlaybackClock().unavailableHelp == nil)
}

@Test(arguments: playbackClocks)
func clockLoopWrapsToZero(clock: any PlaybackClock) {
    #expect(clock.tick(startFrame: 50, elapsed: 1, framesPerSecond: 24, durationFrames: 60, loops: true)
        == HaloPlaybackTick(frame: 14, ended: false))
    #expect(clock.tick(startFrame: 59, elapsed: 1.0 / 24, framesPerSecond: 24, durationFrames: 60, loops: true)
        == HaloPlaybackTick(frame: 0, ended: false))
}

@Test(arguments: playbackClocks)
func clockPlayOnceStopsOnTheLastFrame(clock: any PlaybackClock) {
    #expect(clock.tick(startFrame: 0, elapsed: 0.7, framesPerSecond: 30, durationFrames: 60, loops: false)
        == HaloPlaybackTick(frame: 21, ended: false))
    #expect(clock.tick(startFrame: 50, elapsed: 1, framesPerSecond: 24, durationFrames: 60, loops: false)
        == HaloPlaybackTick(frame: 59, ended: true))
    #expect(clock.tick(startFrame: 0, elapsed: 1e300, framesPerSecond: 24, durationFrames: 60, loops: false)
        == HaloPlaybackTick(frame: 59, ended: true))
}

@Test(arguments: playbackClocks)
func clockStaysOnStartFrameForNoTime(clock: any PlaybackClock) {
    for elapsed in [Double.nan, .infinity, -1, 0] {
        #expect(clock.tick(startFrame: 7, elapsed: elapsed, framesPerSecond: 24, durationFrames: 60, loops: true)
            == HaloPlaybackTick(frame: 7, ended: false))
    }
    #expect(clock.tick(startFrame: 7, elapsed: 1, framesPerSecond: 0, durationFrames: 60, loops: true)
        == HaloPlaybackTick(frame: 0, ended: false))
    #expect(clock.tick(startFrame: 7, elapsed: 1, framesPerSecond: 24, durationFrames: 0, loops: true).frame == 0)
}
