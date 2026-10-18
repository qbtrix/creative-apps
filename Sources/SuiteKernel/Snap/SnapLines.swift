// SnapLines.swift: the alignment-line engine (editor-kernel EK-29 stub; the
// snapping feature's SN-2 fills the body). Given the candidate frames, it
// finds the offset that lines a moving box's edges or centre up with one of
// theirs within a tolerance, and the lines to draw once it has snapped.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Alignment lines against a set of candidate frames.
public struct SnapLines: Sendable {
    /// The frames the lines come from.
    let candidates: [SnapCandidate]

    /// An engine over the candidates `c`.
    public init(_ c: [SnapCandidate]) { candidates = c }

    /// The smallest offset on `axis` that lines one of `values` (a box's
    /// edges and centre) up with a candidate within `tolerance`; nil when none
    /// is that close. Stub: nil.
    public func offset(_ axis: SnapLine.Axis, for values: [Double], tolerance: Double) -> Double? { nil }

    /// The lines `box` sits on, to draw. Stub: none.
    public func lines(on box: Rect) -> [SnapLine] { [] }
}
