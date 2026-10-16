// TimelineEdits.swift: the timeline's drag rules, pure and Foundation only.
// SuiteTimelineEditing is the live TimelineEditing (Contracts/
// TimelineEditing.swift): a frame snaps to the playhead when their ticks are
// within the radius in points (a tie goes to the playhead), and a trim keeps
// its span inside 0...lastFrame, never shorter than one frame, the other edge
// fixed (the Fake never snaps and lets a span collapse to one tick). The work
// area's handles trim by the same rule. TimelineDragSteps is the key-drag step
// rule: a drag works out a running total of frames moved, and the host is sent
// only the change since its last send, and nothing when the total repeats, so
// one drag is a handful of frame steps, not one call per pointer sample. The
// lane's key drag (TL-14) and trim (TL-15) call these; no SwiftUI type appears
// here.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteTimelineEditing: TimelineEditing {
    public init() {}

    public func snapped(_ frame: Int, playhead: Int, radius: Double, scale: TimelineScale) -> Int {
        let width = scale.frameWidth
        guard width > 0, width.isFinite, radius.isFinite else { return frame }
        // Each tick's x is its frame times the width; Doubles, so far-apart frames can't overflow.
        let distance = abs(Double(frame) * width - Double(playhead) * width)
        return distance <= radius ? playhead : frame
    }

    public func trimmed(_ span: ClosedRange<Int>, edge: SpanEdge, to frame: Int, lastFrame: Int) -> ClosedRange<Int> {
        let last = max(lastFrame, 0)
        let lo = min(max(span.lowerBound, 0), last)
        let hi = min(max(span.upperBound, 0), last)
        switch edge {
        case .start:
            // At least one frame before the fixed end, never before 0 (a span at 0...0 stays there).
            let start = min(max(min(frame, hi - 1), 0), hi)
            return start...hi
        case .end:
            let least = lo < last ? lo + 1 : lo
            let end = max(min(max(frame, least), last), lo)
            return lo...end
        }
    }
}

/// The key-drag step rule: a running total of frames moved in, the change since the last send out.
public struct TimelineDragSteps: Equatable, Sendable {
    /// The total the host has been sent so far in this drag.
    public private(set) var lastSent = 0

    public init() {}

    /// The frames to send for the drag's new running `total`: nil when it matches what was sent.
    public mutating func step(toTotal total: Int) -> Int? {
        guard total != lastSent else { return nil }
        let delta = total - lastSent
        lastSent = total
        return delta
    }
}
