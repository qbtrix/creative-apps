// PlaybackClockContractTests.swift: what every PlaybackClock promises (#37),
// run over each conforming type in `playbackClocks`; the live type joins by
// adding itself there. The edges match FlareCore's playbackFrame. Runs on
// Linux and macOS.
import HaloModel
import Testing

let playbackClocks: [any PlaybackClock] = [FakePlaybackClock()]

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
    #expect(clock.tick(startFrame: 7, elapsed: 1, framesPerSecond: 0, durationFrames: 60, loops: true).frame == 7)
    #expect(clock.tick(startFrame: 7, elapsed: 1, framesPerSecond: 24, durationFrames: 0, loops: true).frame == 0)
}
