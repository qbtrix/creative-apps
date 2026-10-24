// Playback/PlaybackBudget.swift: QB-L4's playback gate (docs/review-rubric.md, section 6), one copy for every player
// (#5077): play at the document rate for 5 s and count the document frames the run skipped. A step of n frames
// forward drops n - 1, across the loop's wrap too; repeats drop none. Linux-safe.

/// QB-L4: play at the document rate for 5 s.
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
