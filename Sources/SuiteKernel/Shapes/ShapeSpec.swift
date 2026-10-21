// ShapeSpec.swift (shape-tools SH-1, complete): what the shape tool draws, the
// recipe a shape layer keeps so a resize redraws it and a save keeps its options.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// The six shapes the shape tool draws.
public enum ShapeKind: String, Codable, CaseIterable, Sendable { case rectangle, ellipse, polygon, star, line, arrow }

/// A drawn shape's recipe: a polygon's sides, a star's points and inner radius over outer (0.1...1), a
/// rectangle's corner radius and an arrow's head (points), and a line's ends in the box's unit space.
public struct ShapeSpec: Hashable, Sendable, Codable {
    public var kind: ShapeKind, sides: Int, points: Int, innerRatio: Double
    public var cornerRadius: Double, head: Double, start: Point, end: Point

    public init(kind: ShapeKind, sides: Int = 5, points: Int = 5, innerRatio: Double = 0.5, cornerRadius: Double = 0,
                head: Double = 12, start: Point = Point(x: 0, y: 0), end: Point = Point(x: 1, y: 1)) {
        (self.kind, self.sides, self.points, self.innerRatio) = (kind, sides, points, innerRatio)
        (self.cornerRadius, self.head, self.start, self.end) = (cornerRadius, head, start, end)
    }

    /// `kind`'s options before anyone changes them: 5 sides, 5 points at 0.5, radius 0, head 12, a line corner to corner.
    public static func defaults(_ kind: ShapeKind) -> ShapeSpec { ShapeSpec(kind: kind) }
}
