// SnapGaps.swift: the gap and even-spacing engine (editor-kernel EK-29 stub;
// the snapping feature's SN-3 fills the body). Given the candidate frames, it
// finds the offset that makes a moving box's gap to its neighbours match the
// spacing already between them, and the gaps to label once it has snapped.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Gaps and spacing matches against a set of candidate frames.
public struct SnapGaps: Sendable {
    /// The frames the gaps are measured between.
    let candidates: [SnapCandidate]

    /// An engine over the candidates `c`.
    public init(_ c: [SnapCandidate]) { candidates = c }

    /// The offset on `axis` that gives `box` the same spacing as its
    /// neighbours within `tolerance`; nil when no spacing is that close. Stub: nil.
    public func spacingOffset(_ axis: SnapLine.Axis, for box: Rect, tolerance: Double) -> Double? { nil }

    /// The gaps around `box`, to label. Stub: none.
    public func gaps(around box: Rect) -> [SnapGap] { [] }
}
