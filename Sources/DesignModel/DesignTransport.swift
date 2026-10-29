// DesignTransport.swift: Design's play state on the suite's one clock (one-document OD-11). Playing adds up the
// seconds since play began and turns the total into a frame through SuiteKernel's PlaybackTiming at the document's
// rate and length, so frames never drift and a late refresh skips frames instead of slowing play. Play once ends
// on the last frame (play there starts over); loop wraps. Pause keeps the frame; stop drops it, back to the rest
// pose. Shown state only, like the playhead: `DesignWorkspace.show(_:)` moves the playhead and nothing else, so
// playing never reaches the history, autosave or the saved marker. The window ticks it on the canvas's live copy
// (DesignWindow+Playback.swift), so a tick runs the canvas alone. Linux-safe.
import SuiteKernel

public struct DesignTransport: Sendable, Equatable {
    public private(set) var isPlaying = false
    public var loops = false
    /// The frame shown: nil before play and after stop (the rest pose).
    public private(set) var frame: Int?
    private var startFrame = 0
    private var elapsed = 0.0

    public init() {}

    /// Starts on `playhead` (the rest pose plays from frame 0), clamped to `time`'s frames.
    public mutating func play(from playhead: Int?, time: DesignDocumentTime) {
        let last = max(time.durationFrames - 1, 0)
        var start = min(max(playhead ?? 0, 0), last)
        if !loops, start >= last { start = 0 }
        (startFrame, elapsed, frame, isPlaying) = (start, 0, start, true)
    }

    /// Plays `seconds` more and returns the frame to show; a step that isn't a positive time changes nothing.
    @discardableResult
    public mutating func tick(by seconds: Double, time: DesignDocumentTime) -> Int? {
        guard isPlaying, seconds.isFinite, seconds > 0 else { return frame }
        elapsed += seconds
        let next = PlaybackTiming.tick(startFrame: startFrame, elapsed: elapsed, rate: time.rate,
                                       durationFrames: time.durationFrames, mode: loops ? .loop : .once)
        frame = next.frame
        if next.ended { isPlaying = false }
        return frame
    }

    public mutating func pause() { isPlaying = false }

    public mutating func stop() { isPlaying = false }
}

extension DesignWorkspace {
    /// Shows `transport`'s frame: the playhead moves, nothing else. Never an edit.
    public mutating func show(_ transport: DesignTransport) { setPlayhead(transport.frame) }
}
