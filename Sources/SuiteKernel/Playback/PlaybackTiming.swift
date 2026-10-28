// Playback/PlaybackTiming.swift: the suite's one playback clock rule (#5077). It maps seconds played from a start
// frame onto the frame that shows, at a timeline's exact rate (23.976 plays 24000 frames per 1001 s), through
// FlareCore's `Timeline.playbackFrame`, which floors with the shared 1e-9 frame-edge epsilon. The frame comes from
// the total time, never from a count of ticks, so a dropped refresh lands straight on the clock's frame and long runs
// never drift. Once ends after the last frame has had its time; loop wraps to 0; ping-pong runs 0…n-1…0 and never
// ends. Total: no input traps. Apps keep their own transport state and call this; Linux-safe.
import FlareCore

/// How a play treats the timeline's end.
public enum PlaybackMode: Sendable, Hashable, CaseIterable {
    /// Plays to the last frame and ends there.
    case once
    /// Wraps from the last frame to the first.
    case loop
    /// Runs forward to the last frame, back to the first, and on; never ends.
    case pingPong
}

/// Where playback is after a tick.
public struct PlaybackTick: Sendable, Hashable {
    public var frame: Int
    /// True once a play-once has given its last frame its time; the player stops then.
    public var ended: Bool
    public init(frame: Int, ended: Bool) { self.frame = frame; self.ended = ended }
}

/// The playback clock: elapsed seconds in, the frame that shows out.
public enum PlaybackTiming {
    /// The frame `elapsed` seconds after play began on `startFrame` (clamped to the timeline) of a
    /// `durationFrames`-frame timeline at `rate`. No time (not finite, at or below 0) holds the start frame; an empty
    /// timeline or a rate at or below 0 is frame 0.
    public static func tick(startFrame: Int, elapsed: Double, rate: FrameRate, durationFrames: Int,
                            mode: PlaybackMode) -> PlaybackTick {
        guard durationFrames > 0, rate.numerator > 0 else { return PlaybackTick(frame: 0, ended: false) }
        let last = durationFrames - 1
        let start = min(max(startFrame, 0), last)
        guard elapsed.isFinite, elapsed > 0 else { return PlaybackTick(frame: start, ended: false) }
        let seconds = elapsed + rate.seconds(ofFrame: start)
        let scene = SceneRate(numerator: rate.numerator, denominator: rate.denominator)
        func frame(over frames: Int, loop: Bool) -> Int? {
            try? Timeline.playbackFrame(elapsed: seconds, rate: scene, durationFrames: frames, loop: loop)
        }
        switch mode {
        case .once:
            let ended = seconds * Double(rate.numerator) / Double(rate.denominator) >= Double(durationFrames)
            return PlaybackTick(frame: frame(over: durationFrames, loop: false) ?? start, ended: ended)
        case .loop:
            return PlaybackTick(frame: frame(over: durationFrames, loop: true) ?? start, ended: false)
        case .pingPong:
            let (period, overflow) = last.multipliedReportingOverflow(by: 2)
            guard last > 0, !overflow, let m = frame(over: period, loop: true) else {
                return PlaybackTick(frame: frame(over: durationFrames, loop: false) ?? start, ended: false)
            }
            return PlaybackTick(frame: m <= last ? m : period - m, ended: false)
        }
    }
}
