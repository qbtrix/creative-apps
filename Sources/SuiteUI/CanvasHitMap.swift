// CanvasHitMap.swift: which mark sits under a point on the canvas host (CH-6).
// Marks are rects and stroked paths in document points, kept bottom to top.
// A point hits a mark within `slop` points of its edge (4 pt by default,
// QB-S20); of the marks it hits, the nearest wins, and on a tie (overlapping
// marks the point is inside) the topmost. Pure geometry: no view reads it yet.
import CoreGraphics
import Foundation

/// One mark the hit map knows: an id the caller owns and the shape it covers.
public struct CanvasHitMark: Equatable, Sendable {
    /// The area a mark covers, in document points.
    public enum Shape: Equatable, Sendable {
        /// A filled rectangle: a point inside it is at distance 0.
        case rect(CGRect)
        /// A polyline stroked `width` points wide; `closed` joins the last point to the first.
        case path(points: [CGPoint], width: CGFloat, closed: Bool)
    }

    public let id: String
    public let shape: Shape

    public init(id: String, shape: Shape) {
        self.id = id
        self.shape = shape
    }

    /// How far `point` lies outside the mark's edge; 0 inside it, nil for a path with no points.
    public func distance(to point: CGPoint) -> CGFloat? {
        switch shape {
        case let .rect(rect):
            let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
            let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
            return (dx * dx + dy * dy).squareRoot()
        case let .path(points, width, closed):
            guard let first = points.first else { return nil }
            var segments = Array(zip(points, points.dropFirst()))
            if closed, let last = points.last, points.count > 2 { segments.append((last, first)) }
            let centre = segments.isEmpty
                ? Self.length(point.x - first.x, point.y - first.y)
                : segments.map { Self.distance(from: point, toSegment: $0.0, $0.1) }.min() ?? 0
            return max(centre - max(width, 0) / 2, 0)
        }
    }

    private static func length(_ dx: CGFloat, _ dy: CGFloat) -> CGFloat {
        (dx * dx + dy * dy).squareRoot()
    }

    private static func distance(from point: CGPoint, toSegment start: CGPoint, _ end: CGPoint) -> CGFloat {
        let ex = end.x - start.x, ey = end.y - start.y
        let lengthSquared = ex * ex + ey * ey
        guard lengthSquared > 0 else { return length(point.x - start.x, point.y - start.y) }
        let along = ((point.x - start.x) * ex + (point.y - start.y) * ey) / lengthSquared
        let t = min(max(along, 0), 1)
        return length(point.x - (start.x + t * ex), point.y - (start.y + t * ey))
    }
}

/// Which marks sit under a point. Marks are added bottom to top; `hit` names the one a click picks.
public struct CanvasHitMap: Equatable, Sendable {
    /// The default reach past a mark's edge that still hits, in points (QB-S20).
    public static let defaultSlop: CGFloat = 4

    /// The marks, bottom first: a later mark draws over an earlier one.
    public private(set) var marks: [CanvasHitMark] = []
    /// How far past a mark's edge a point still hits it, in points.
    public let slop: CGFloat

    public init(slop: CGFloat = CanvasHitMap.defaultSlop) {
        self.slop = max(slop, 0)
    }

    /// Adds a filled rect on top of every mark so far.
    public mutating func addRect(id: String, _ rect: CGRect) {
        marks.append(CanvasHitMark(id: id, shape: .rect(rect.standardized)))
    }

    /// Adds a stroked path on top of every mark so far.
    public mutating func addPath(id: String, points: [CGPoint], width: CGFloat, closed: Bool = false) {
        marks.append(CanvasHitMark(id: id, shape: .path(points: points, width: width, closed: closed)))
    }

    /// Drops every mark, keeping the slop.
    public mutating func removeAll() {
        marks.removeAll()
    }

    /// The id of the nearest mark within `slop` of `point`, the topmost on a tie; nil when none is in reach.
    public func hit(_ point: CGPoint) -> String? {
        var best: (id: String, distance: CGFloat)?
        for mark in marks.reversed() {
            guard let distance = mark.distance(to: point), distance <= slop else { continue }
            if best.map({ distance < $0.distance }) ?? true {
                best = (mark.id, distance)
            }
        }
        return best?.id
    }
}
