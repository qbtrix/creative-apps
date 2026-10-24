// Live/HaloPlaybackClock+Kernel.swift: the live PlaybackClock (#37), an adapter onto the suite's playback clock
// (SuiteKernel `PlaybackTiming`, #5077), which loops or plays once at the exact rate with FlareCore's 1e-9 frame-edge
// epsilon; play-once ends once the last frame has had its time. The fake wraps this type, so the two cannot
// disagree. Linux-safe.
import SuiteKernel

public struct LivePlaybackClock: PlaybackClock {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func tick(
        startFrame: Int, elapsed: Double, rate: FrameRate, durationFrames: Int, loops: Bool
    ) -> HaloPlaybackTick {
        PlaybackTiming.tick(
            startFrame: startFrame, elapsed: elapsed, rate: rate, durationFrames: durationFrames, mode: loops ? .loop : .once)
    }
}
