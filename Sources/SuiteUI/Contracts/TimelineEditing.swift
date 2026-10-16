// TimelineEditing.swift: the values the timeline strip's API passes (unit,
// span edge, pick mode) and the snap and trim rules, with
// FakeTimelineEditing, which never snaps and trims with no one-frame floor on
// purpose. Foundation only; from the timeline packet's Contract slice. The
// live rules are TL-13's SuiteTimelineEditing.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// How the ruler, the playhead pill and a host's readout show time.
public enum TimeUnit: String, Hashable, Sendable, CaseIterable { case frames, timecode }

/// Which end of a span (a clip or the work area) a trim moves.
public enum SpanEdge: String, Hashable, Sendable { case start, end }

/// How a key press changes the picked keys: replace them, add the key, or toggle it.
public enum PickMode: String, Hashable, Sendable { case replace, extend, toggle }

public protocol TimelineEditing: Sendable {
    /// `frame`, or `playhead` when their ticks are within `radius` points (a tie goes to the playhead).
    func snapped(_ frame: Int, playhead: Int, radius: Double, scale: TimelineScale) -> Int
    /// `span` with `edge` at `frame`: inside 0...lastFrame, never shorter than one frame, the other edge fixed.
    /// The work area moves its handles by the same rule.
    func trimmed(_ span: ClosedRange<Int>, edge: SpanEdge, to frame: Int, lastFrame: Int) -> ClosedRange<Int>
}

/// Never snaps; trims with no one-frame floor (an edge past the other gives frame...frame).
public struct FakeTimelineEditing: TimelineEditing {
    public init() {}
    public func snapped(_ frame: Int, playhead: Int, radius: Double, scale: TimelineScale) -> Int { frame }
    public func trimmed(_ span: ClosedRange<Int>, edge: SpanEdge, to frame: Int, lastFrame: Int) -> ClosedRange<Int> {
        let f = min(max(frame, 0), max(lastFrame, 0))
        switch edge {
        case .start: return f <= span.upperBound ? f...span.upperBound : f...f
        case .end: return f >= span.lowerBound ? span.lowerBound...f : f...f
        }
    }
}
