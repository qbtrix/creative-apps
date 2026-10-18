// CurvePointEditing.swift: UC15 (SJ16, SJ20), adding, moving, nudging and
// removing tone-curve points, and FakeCurvePointEditing, which appends unsorted
// and never refuses a removal on purpose. Foundation only; verbatim from
// blueprint section 5.2.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public protocol CurvePointEditing: Sendable {
    /// Unit points (0...1 both ways), sorted by x, at least two. A click adds a point between its neighbours.
    func added(_ point: PlanePoint, to points: [PlanePoint]) -> (points: [PlanePoint], index: Int)?
    /// Moved, kept between its neighbours with a minimum gap; the ends keep their x.
    func moved(_ index: Int, to point: PlanePoint, in points: [PlanePoint]) -> [PlanePoint]
    /// Nil when the point is an end or the curve would drop under two points.
    func removed(_ index: Int, from points: [PlanePoint]) -> [PlanePoint]?
    /// Arrow nudges of 0.01, ⇧ 0.1.
    func nudged(_ index: Int, dx: Int, dy: Int, coarse: Bool, in points: [PlanePoint]) -> [PlanePoint]
    /// Whether a drag at `location` (points, in a well of `extent`) has left the well, which removes a middle point.
    func isOutOfWell(_ location: PlanePoint, extent: PlaneExtent) -> Bool
}

/// Appends without sorting and never refuses a removal.
public struct FakeCurvePointEditing: CurvePointEditing {
    public init() {}
    public func added(_ point: PlanePoint, to points: [PlanePoint]) -> (points: [PlanePoint], index: Int)? {
        (points + [point], points.count)
    }
    public func moved(_ index: Int, to point: PlanePoint, in points: [PlanePoint]) -> [PlanePoint] {
        guard points.indices.contains(index) else { return points }
        var p = points; p[index] = point; return p
    }
    public func removed(_ index: Int, from points: [PlanePoint]) -> [PlanePoint]? {
        guard points.indices.contains(index) else { return nil }
        var p = points; p.remove(at: index); return p
    }
    public func nudged(_ index: Int, dx: Int, dy: Int, coarse: Bool, in points: [PlanePoint]) -> [PlanePoint] {
        guard points.indices.contains(index) else { return points }
        let s = coarse ? 0.1 : 0.01
        return moved(index, to: PlanePoint(x: points[index].x + Double(dx) * s, y: points[index].y + Double(dy) * s), in: points)
    }
    /// Out only past the well's edge, with no margin (the live rule has one).
    public func isOutOfWell(_ location: PlanePoint, extent: PlaneExtent) -> Bool {
        location.x < 0 || location.y < 0 || location.x > extent.width || location.y > extent.height
    }
}
