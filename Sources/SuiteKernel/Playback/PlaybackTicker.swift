// Playback/PlaybackTicker.swift: the suite's one display-link ticker (#5077). A display link (SuiteUI's
// SuitePlaybackDriver) hands each refresh's target timestamp, the time that frame reaches the screen, never wall time;
// the ticker turns consecutive targets into the elapsed seconds between them. Invariants: the first tick after a
// reset only sets the baseline, so a pause never counts as play time; a target that is not finite or not later than
// the previous one is ignored and the baseline stays put. Linux-safe.

/// Turns display-link target timestamps (seconds on the link's clock) into elapsed seconds between ticks.
public struct PlaybackTicker: Sendable, Equatable {
    /// The previous tick's target timestamp; nil before the first tick after a reset.
    public private(set) var lastTarget: Double?

    public init() {}

    /// Forgets the baseline: the next tick starts timing afresh. An app starts a fresh ticker, or calls this, on each play.
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
