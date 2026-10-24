// Fakes/FakePlaybackClock.swift: the PlaybackClock the fake services use
// (#37). A thin wrapper over `LivePlaybackClock`, so the playback rule exists
// once and fake and live agree on every frame. Linux-safe.

import SuiteKernel

public struct FakePlaybackClock: PlaybackClock {
    public init() {}
    public func tick(
        startFrame: Int, elapsed: Double, rate: FrameRate, durationFrames: Int, loops: Bool
    ) -> HaloPlaybackTick {
        LivePlaybackClock().tick(
            startFrame: startFrame, elapsed: elapsed, rate: rate, durationFrames: durationFrames, loops: loops)
    }
}
