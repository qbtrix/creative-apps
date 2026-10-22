// SpanRules.swift (timeline-keys TK-1 stub, TK-5 body): sliding a layer's span
// on the timeline. The span and every key on its tracks move by one delta,
// `by` clamped so the span stays inside 0...lastFrame; the keys move through
// `KeyRules.moveKeys`, so a key that would leave the range refuses the whole
// slide and nothing changes.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The span rules every timeline app's layer bar uses.
public enum SpanRules {
    /// Slides `span` and every key in `tracks` by `by`, clamped to keep the
    /// span in 0...lastFrame, and returns the delta applied (0 moves nothing).
    /// Throws `KeyRefusal` with both untouched when a key would leave the range.
    @discardableResult
    public static func slide(
        _ span: inout ClosedRange<Int>, tracks: inout [String: [Keyframe]], by: Int, lastFrame: Int
    ) throws(KeyRefusal) -> Int {
        guard lastFrame >= 0 else { throw .pastRange(frame: span.upperBound) }
        let (earliest, under) = 0.subtractingReportingOverflow(span.lowerBound)
        let (latest, over) = lastFrame.subtractingReportingOverflow(span.upperBound)
        guard !under, !over else { throw .pastRange(frame: under ? span.lowerBound : span.upperBound) }
        let delta = max(earliest, min(by, latest))
        guard delta != 0 else { return 0 }
        let keyed = Set(tracks.values.flatMap { $0.map(\.frame) })
        try KeyRules.moveKeys(&tracks, keyed, by: delta, clampedTo: 0...lastFrame)
        span = (span.lowerBound + delta)...(span.upperBound + delta)
        return delta
    }
}
