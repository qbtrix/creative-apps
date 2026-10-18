// Stroke.swift: the stroke model's samples and segments (editor-kernel
// EK-29 stubs, EK-28 bodies). A drag arrives as `StrokeSample`s (a point, a
// pressure, a time); `StrokeSmoother` turns them into cubic `StrokeSegment`s
// with a pressure range (centripetal Catmull-Rom, one segment late, mirrored
// ends) and flattens a segment into points; `DabSpacer` spaces the dabs a
// brush stamps between two points. Every app that paints uses these, never a
// copy. The stubs return fake values and never trap; EK-28 fills the bodies.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One pointer sample of a stroke: where (document space), how hard and
/// when (seconds from any fixed start).
public struct StrokeSample: Hashable, Sendable {
    /// The sample's point in document space.
    public var point: Point
    /// The pen pressure, 0...1. EK-28 clamps it and reads NaN as 1 (a mouse
    /// has no pressure, so it paints at full).
    public var pressure: Double
    /// When the sample was taken.
    public var time: TimeInterval

    /// A sample at `point` with `pressure` (default full) taken at `time`.
    public init(point: Point, pressure: Double = 1, time: TimeInterval = 0) {
        (self.point, self.pressure, self.time) = (point, pressure, time)
    }
}

/// One cubic piece of a smoothed stroke: from `p0` through the handles `c1`
/// and `c2` to `p1`, with the pressure it starts and ends at as a range.
public struct StrokeSegment: Hashable, Sendable {
    /// The start, its handle, the end's handle and the end.
    public var p0: Point, c1: Point, c2: Point, p1: Point
    /// The lower and upper pressure along the segment.
    public var pressure: ClosedRange<Double>

    /// A segment from its four points and its pressure range.
    public init(p0: Point, c1: Point, c2: Point, p1: Point, pressure: ClosedRange<Double>) {
        (self.p0, self.c1, self.c2, self.p1, self.pressure) = (p0, c1, c2, p1, pressure)
    }
}

/// Turns a drag's samples into smooth cubic segments as they arrive.
/// EK-28: it keeps the last four samples and, with four, emits the segment
/// between the middle two (so it runs one segment late), drops a sample that
/// repeats the last point, mirrors the first point across the second at the
/// start, and `finish` mirrors the far end to emit the last segment.
public struct StrokeSmoother: Sendable {
    /// An empty smoother, ready for a stroke's first sample.
    public init() {}

    /// Adds a sample; returns the segment it completes, or nil while the
    /// smoother still waits for more. Stub: always nil.
    public mutating func add(_ s: StrokeSample) -> StrokeSegment? { nil }

    /// Ends the stroke; returns its last segment, or nil when none is left.
    /// Stub: always nil.
    public mutating func finish() -> StrokeSegment? { nil }

    /// The segment as points to draw through, at most `tolerance` off the
    /// curve. EK-28: n = ceil(sqrt(3 · bend)) pieces, clamped to 1...64, so
    /// n + 1 points. Stub: the two ends.
    public static func flattened(_ seg: StrokeSegment, tolerance: Double) -> [Point] { [seg.p0, seg.p1] }
}

/// Where a brush stamps its dabs between two points.
public enum DabSpacer {
    /// The dab centres from `a` towards `b`, `spacing` apart (EK-28: spacing
    /// floored at 1, at most `cap` dabs). Stub: `a` alone.
    public static func centers(_ a: Point, _ b: Point, spacing: Double, cap: Int = 10_000) -> [Point] { [a] }
}

extension StrokeSample {
    /// The fixture stroke: 40 samples along a shallow arc from x 100 to
    /// x 490, 1/120 s apart, pressure rising from 0.3 to full at the middle
    /// and falling back. The stroke tests and the gallery's stroke pad draw it.
    public static let strokeSamples: [StrokeSample] = (0..<40).map { i in
        let offset = Double(i) - 20
        return StrokeSample(point: Point(x: 100 + Double(i) * 10, y: 200 + offset * offset / 4),
                            pressure: 0.3 + 0.7 * (1 - abs(offset) / 20), time: Double(i) / 120)
    }
}
