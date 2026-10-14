// FlarePlaybackTicks.swift: the platform-neutral half of the playback driver (docs/blueprints/flare.md, 7.5, LA-2).
// A display link (PlaybackDriver in FlareApp, on macOS) hands each refresh's target timestamp to
// `FlareWorkspace.tick(target:ticker:)`; `PlaybackTicker` turns consecutive targets into the elapsed seconds LM-7's
// `advance(elapsed:)` takes. Using the link's target time, never wall time, keeps the playhead on the frame the
// screen is about to show. The first tick after a start only sets the baseline, so a pause never counts as elapsed
// play time. `PlaybackBudget` holds QB-L4's CI gate and counts the document frames a run skipped.

/// Turns display-link target timestamps (seconds on the link's clock) into elapsed seconds between ticks.
public struct PlaybackTicker: Sendable, Equatable {
    /// The previous tick's target timestamp; nil before the first tick after a reset.
    public private(set) var lastTarget: Double?

    public init() {}

    /// Forgets the baseline: the next tick starts timing afresh. The driver calls this on start and stop.
    public mutating func reset() {
        lastTarget = nil
    }

    /// The seconds from the previous tick's target to `target`; nil for the first tick after a reset, and for a
    /// target that is not finite or not later than the previous one (the baseline stays put).
    public mutating func elapsed(toTarget target: Double) -> Double? {
        guard target.isFinite else { return nil }
        guard let last = lastTarget else { lastTarget = target; return nil }
        guard target > last else { return nil }
        lastTarget = target
        return target - last
    }
}

extension FlareWorkspace {
    /// The display link's entry point: one call per refresh with the frame's target timestamp. Moves the play clock
    /// through `advance(elapsed:)` and returns whether playback is still running; the driver stops its link on false.
    /// Paused, it moves nothing and resets the ticker, so the next play starts timing from its first tick.
    public mutating func tick(target: Double, ticker: inout PlaybackTicker) -> Bool {
        guard isPlaying else { ticker.reset(); return false }
        if let elapsed = ticker.elapsed(toTarget: target) { advance(elapsed: elapsed) }
        if !isPlaying { ticker.reset() }
        return isPlaying
    }
}

/// QB-L4 (docs/review-rubric.md, section 6): play at the document rate for 5 s.
public enum PlaybackBudget {
    /// How long the check plays, in seconds.
    public static let seconds: Double = 5
    /// The CI gate: at most this many document frames dropped in `seconds` (the device target is 0).
    public static let ciMaxDroppedFrames = 2

    /// The document frames skipped between consecutive playhead positions on a looping timeline of
    /// `timelineFrames` frames: a step of n frames forward drops n - 1. Repeats (a step of 0) drop none.
    public static func droppedFrames(in frames: [Int], timelineFrames: Int) -> Int {
        guard timelineFrames > 0 else { return 0 }
        return zip(frames, frames.dropFirst()).reduce(0) { dropped, pair in
            let step = ((pair.1 - pair.0) % timelineFrames + timelineFrames) % timelineFrames
            return dropped + max(step - 1, 0)
        }
    }
}
