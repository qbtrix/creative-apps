// Live/LivePlaybackClock.swift: the live PlaybackClock (#37), the one home of
// the playback rule. It maps elapsed seconds from a start frame onto
// FlareCore's `Timeline.playbackFrame`, which loops or clamps and shares the
// 1e-9 frame-edge epsilon; play-once ends on the last frame. The fake wraps
// this type, so the two cannot disagree. Linux-safe.
import FlareCore

public struct LivePlaybackClock: PlaybackClock {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func tick(
        startFrame: Int, elapsed: Double, framesPerSecond: Int, durationFrames: Int, loops: Bool
    ) -> HaloPlaybackTick {
        guard durationFrames > 0, framesPerSecond > 0 else { return HaloPlaybackTick(frame: 0, ended: false) }
        let start = max(0, min(startFrame, durationFrames - 1))
        guard elapsed.isFinite, elapsed > 0 else { return HaloPlaybackTick(frame: start, ended: false) }
        let frame = (try? Timeline.playbackFrame(
            elapsed: elapsed + Double(start) / Double(framesPerSecond), fps: framesPerSecond,
            durationFrames: durationFrames, loop: loops)) ?? start
        return HaloPlaybackTick(frame: frame, ended: !loops && frame == durationFrames - 1)
    }
}
