// Stroke.swift: the stroke model's samples and segments (editor-kernel
// EK-29 stubs, EK-28 bodies). A drag arrives as `StrokeSample`s (a point, a
// pressure, a time); `StrokeSmoother` turns them into cubic `StrokeSegment`s
// with a pressure range (centripetal Catmull-Rom, one segment late, mirrored
// ends) and flattens a segment into points; `DabSpacer` spaces the dabs a
// brush stamps between two points. Every app that paints uses these, never a
// copy. Nothing here traps: every count is clamped before it becomes an Int.
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
/// It keeps the last four samples and, with four, emits the segment between
/// the middle two (so it runs one segment late) and drops a sample that
/// repeats the last point. `finish` mirrors the far end to emit the last
/// segment; on a two-sample stroke it mirrors the start across the second
/// point too. Pressure is clamped to 0...1 and NaN reads as 1.
public struct StrokeSmoother: Sendable {
    /// The last four distinct samples, pressures already read.
    private var recent: [StrokeSample] = []

    /// An empty smoother, ready for a stroke's first sample.
    public init() {}

    /// Adds a sample; returns the segment it completes, or nil while the
    /// smoother still waits for more.
    public mutating func add(_ s: StrokeSample) -> StrokeSegment? {
        var s = s
        s.pressure = Self.read(s.pressure)
        if recent.last?.point == s.point { return nil }
        recent.append(s)
        if recent.count > 4 { recent.removeFirst(recent.count - 4) }
        guard recent.count == 4, let before = recent.first, let after = recent.last else { return nil }
        return Self.segment(before.point, recent[1], recent[2], after.point)
    }

    /// Ends the stroke; returns its last segment, or nil when none is left.
    /// The smoother is empty again afterwards.
    public mutating func finish() -> StrokeSegment? {
        defer { recent = [] }
        let tail = Array(recent.suffix(3))
        guard tail.count >= 2 else { return nil }
        let a = tail[tail.count - 2], b = tail[tail.count - 1]
        let before = tail.count == 3 ? tail[0].point : Self.mirror(b.point, across: a.point)
        return Self.segment(before, a, b, Self.mirror(a.point, across: b.point))
    }

    /// The segment as points to draw through, at most `tolerance` off the
    /// curve: n = ceil(sqrt(3 · bend)) pieces, bend being the larger second
    /// difference over 4 · tolerance, clamped to 1...64, so n + 1 points.
    public static func flattened(_ seg: StrokeSegment, tolerance: Double) -> [Point] {
        let tol = tolerance > 0 ? tolerance : 0.25
        let dd = Swift.max(length(seg.p0.x - 2 * seg.c1.x + seg.c2.x, seg.p0.y - 2 * seg.c1.y + seg.c2.y),
                           length(seg.c1.x - 2 * seg.c2.x + seg.p1.x, seg.c1.y - 2 * seg.c2.y + seg.p1.y))
        let raw = (3 * dd / (4 * tol)).squareRoot().rounded(.up)
        let n = raw.isFinite ? Int(Swift.min(64, Swift.max(1, raw))) : 64
        let inner = (1..<n).map { i -> Point in
            let t = Double(i) / Double(n), u = 1 - t
            let (w0, w1, w2, w3) = (u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t)
            return Point(x: w0 * seg.p0.x + w1 * seg.c1.x + w2 * seg.c2.x + w3 * seg.p1.x,
                         y: w0 * seg.p0.y + w1 * seg.c1.y + w2 * seg.c2.y + w3 * seg.p1.y)
        }
        return [seg.p0] + inner + [seg.p1]
    }

    /// A pen pressure as a stroke reads it: NaN is full, the rest clamped to 0...1.
    static func read(_ pressure: Double) -> Double {
        pressure.isNaN ? 1 : Swift.min(1, Swift.max(0, pressure))
    }

    static func length(_ dx: Double, _ dy: Double) -> Double { (dx * dx + dy * dy).squareRoot() }

    static func mirror(_ p: Point, across q: Point) -> Point { Point(x: 2 * q.x - p.x, y: 2 * q.y - p.y) }

    /// The centripetal Catmull-Rom piece from `a` to `b` (each knot step the
    /// square root of its chord) as a cubic, between the neighbours `p0` and `p3`.
    static func segment(_ p0: Point, _ a: StrokeSample, _ b: StrokeSample, _ p3: Point) -> StrokeSegment {
        let (p1, p2) = (a.point, b.point)
        let d1 = length(p1.x - p0.x, p1.y - p0.y), d2 = length(p2.x - p1.x, p2.y - p1.y)
        let d3 = length(p3.x - p2.x, p3.y - p2.y), r2 = d2.squareRoot()
        func handle(_ near: Point, _ far: Point, _ back: Point, _ dn: Double) -> Point {
            let rn = dn.squareRoot(), den = 3 * rn * (rn + r2)
            guard den > 0 else { return near }
            let k = 2 * dn + 3 * rn * r2 + d2
            return Point(x: (dn * far.x - d2 * back.x + k * near.x) / den, y: (dn * far.y - d2 * back.y + k * near.y) / den)
        }
        return StrokeSegment(p0: p1, c1: handle(p1, p2, p0, d1), c2: handle(p2, p1, p3, d3), p1: p2,
                             pressure: Swift.min(a.pressure, b.pressure)...Swift.max(a.pressure, b.pressure))
    }
}

/// Where a brush stamps its dabs between two points.
public enum DabSpacer {
    /// The dab centres from `a` towards `b`, `spacing` apart (spacing floored
    /// at 1, NaN read as 1), `a` first, always one and at most `cap` dabs.
    public static func centers(_ a: Point, _ b: Point, spacing: Double, cap: Int = 10_000) -> [Point] {
        let step = spacing >= 1 ? spacing : 1
        let d = StrokeSmoother.length(b.x - a.x, b.y - a.y)
        let room = (d / step).rounded(.down) + 1
        let count = room.isFinite ? Int(Swift.min(Double(Swift.max(cap, 1)), Swift.max(1, room))) : 1
        guard count > 1, d > 0 else { return [a] }
        let (ux, uy) = ((b.x - a.x) / d, (b.y - a.y) / d)
        return (0..<count).map { i in Point(x: a.x + ux * step * Double(i), y: a.y + uy * step * Double(i)) }
    }
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
