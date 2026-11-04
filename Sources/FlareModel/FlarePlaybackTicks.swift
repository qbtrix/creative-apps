// FlarePlaybackTicks.swift: the platform-neutral half of the playback driver (docs/blueprints/flare.md, 7.5, LA-2).
// A display link (SuiteUI's SuitePlaybackDriver, run by FlareApp's FlarePlayer on macOS) hands each refresh's target
// timestamp to `FlareWorkspace.tick(target:ticker:)`; SuiteKernel's `PlaybackTicker` turns consecutive targets into
// the elapsed seconds LM-7's `advance(elapsed:)` takes. Using the link's target time, never wall time, keeps the
// playhead on the frame the screen is about to show. The first tick after a start only sets the baseline, so a pause
// never counts as elapsed play time. The player ticks a copy of the workspace (its clock), never the window's:
// `showing(frame:playing:)` is the window's workspace at the frame on screen, for the stage and the timeline to draw,
// and `landPlayback(from:)` takes the clock's playhead back once, with no undo step and no unsaved change.
// QB-L4's CI gate is SuiteKernel's `PlaybackBudget`.
import SuiteKernel

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

    /// This workspace with its playhead on `frame` (clamped to the timeline) and playing or not: what the canvas draws
    /// while playback runs on a copy. Nothing else changes.
    public func showing(frame: Int, playing: Bool) -> FlareWorkspace {
        var shown = self
        shown.currentFrame = min(max(frame, 0), max(timelineFrames - 1, 0))
        shown.isPlaying = playing && canPlay
        return shown
    }

    /// Takes `clock`'s playback, a copy that played on: its playhead, play clock and whether it still plays, the
    /// playhead clamped to this timeline. Playback is never an undo step or an unsaved change (QB-F3).
    public mutating func landPlayback(from clock: FlareWorkspace) {
        (currentFrame, playClock, isPlaying) = (clock.currentFrame, clock.playClock, clock.isPlaying && canPlay)
        clampPlayhead()
    }
}
