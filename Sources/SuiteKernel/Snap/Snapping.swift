// Snapping.swift: the snap contract (editor-kernel EK-29 stub, EK-18 body).
// A drag snaps to candidate frames: the lines it lines up with (SnapLines,
// snapping SN-2), the even gaps it makes (SnapGaps, snapping SN-3), and the
// offset order lines, then gaps, then whole points. `SnapGuides` is what the
// canvas draws for one drag (SuiteUI's `SnapGuideMarks`) and its `summary`
// the words its accessibility value reads.
//
// `Snapping.candidates(in:moving:drawingInto:page:frame:)` walks EK-2's
// `LayerTree`, which is not on dev yet, so EK-18 declares it with its body.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One alignment line a drag snapped to: on `axis` at `at`, drawn from
/// `from` to `to` along the other axis.
public struct SnapLine: Hashable, Sendable {
    /// Which coordinate a line fixes: `.x` is a vertical line, `.y` a horizontal one.
    public enum Axis: Hashable, Sendable {
        /// A vertical line at an x.
        case x
        /// A horizontal line at a y.
        case y
    }

    /// The axis the line fixes, its coordinate there, and where the drawn
    /// line starts and ends on the other axis.
    public var axis: Axis, at: Double, from: Double, to: Double

    /// A line on `axis` at `at`, drawn from `from` to `to`.
    public init(axis: Axis, at: Double, from: Double, to: Double) {
        (self.axis, self.at, self.from, self.to) = (axis, at, from, to)
    }
}

/// One gap a drag made or matched: along `axis` from `from` to `to`, its
/// mark drawn at `across` on the other axis; `isSpacing` marks a gap that
/// matches its neighbours' spacing.
public struct SnapGap: Hashable, Sendable {
    /// The axis the gap runs along.
    public var axis: SnapLine.Axis
    /// Where the gap starts and ends on `axis`, and where its mark sits across it.
    public var from: Double, to: Double, across: Double
    /// True when the gap matches its neighbours' spacing.
    public var isSpacing: Bool

    /// A gap along `axis` from `from` to `to`, drawn at `across`.
    public init(axis: SnapLine.Axis, from: Double, to: Double, across: Double, isSpacing: Bool) {
        (self.axis, self.from, self.to, self.across, self.isSpacing) = (axis, from, to, across, isSpacing)
    }

    /// The gap's length in whole points, the number its label shows (0 when
    /// the ends are not finite).
    public var length: Int { Snapping.whole(to - from) }
}

/// The guides one drag shows: its lines and its gaps.
public struct SnapGuides: Hashable, Sendable {
    /// The alignment lines, then the gaps and spacing matches.
    public var lines: [SnapLine], gaps: [SnapGap]

    /// Guides from their lines and gaps (default none).
    public init(lines: [SnapLine] = [], gaps: [SnapGap] = []) {
        (self.lines, self.gaps) = (lines, gaps)
    }

    /// No guides.
    public static let empty = SnapGuides()

    /// The fixture the gallery's guide page draws: a vertical line at x 300
    /// between two boxes, a 100-point gap and a 100-point spacing match.
    public static let fake = SnapGuides(
        lines: [SnapLine(axis: .x, at: 300, from: 100, to: 400)],
        gaps: [SnapGap(axis: .x, from: 200, to: 300, across: 150, isSpacing: false),
               SnapGap(axis: .x, from: 300, to: 400, across: 250, isSpacing: true)])

    /// The guides in words, comma separated: "x 300" for a line, "gap x 100"
    /// for a gap, "spacing x 100" for a spacing match; `fake` reads
    /// "x 300, gap x 100, spacing x 100". EK-18 gives it its mutation.
    public var summary: String {
        let lineWords = lines.map { "\($0.axis) \(Snapping.whole($0.at))" }
        let gapWords = gaps.map { "\($0.isSpacing ? "spacing" : "gap") \($0.axis) \($0.length)" }
        return (lineWords + gapWords).joined(separator: ", ")
    }
}

/// One frame a drag can snap to: the layer's `id` (nil for the page) and its
/// frame in document space.
public struct SnapCandidate: Hashable, Sendable {
    /// The layer the frame belongs to (nil for the page), and the frame.
    public var id: String?, frame: Rect

    /// A candidate frame, belonging to layer `id` (nil for the page).
    public init(id: String?, frame: Rect) {
        (self.id, self.frame) = (id, frame)
    }
}

/// The snap rules every app shares.
public enum Snapping {
    /// The offset a drag moves by: the lines' offset when there is one, else
    /// the gaps', else the whole-point rounding (EK-18). Stub: `wholePoints`.
    public static func offset(lines: Double?, gaps: Double?, wholePoints: Double) -> Double {
        wholePoints
    }

    /// `value` rounded to whole points; 0 when it is not finite or too large
    /// for an `Int`, so a label never traps.
    static func whole(_ value: Double) -> Int {
        let rounded = value.rounded()
        guard rounded.isFinite, abs(rounded) < 1e15 else { return 0 }
        return Int(rounded)
    }
}
