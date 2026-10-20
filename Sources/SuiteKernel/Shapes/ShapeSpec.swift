// ShapeSpec.swift (shape-tools SH-1, complete: plain values): what the shape
// tool draws. A spec is the recipe a shape layer keeps, so a resize redraws it
// and a save keeps its points and ratio rather than a flat path.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// The six shapes the shape tool draws.
public enum ShapeKind: String, Codable, CaseIterable, Sendable { case rectangle, ellipse, polygon, star, line, arrow }

/// A drawn shape's recipe. Line and arrow ends are in the box's unit space (0...1), so a resize keeps them.
public struct ShapeSpec: Hashable, Sendable, Codable {
    /// Which shape.
    public var kind: ShapeKind
    /// A polygon's sides; a star's points; a star's inner radius over its outer one (0.1...1).
    public var sides: Int, points: Int, innerRatio: Double
    /// A rectangle's corner radius and an arrow's head length, both in points.
    public var cornerRadius: Double, head: Double
    /// A line's or arrow's ends, in the box's unit space.
    public var start: Point, end: Point

    public init(kind: ShapeKind, sides: Int = 5, points: Int = 5, innerRatio: Double = 0.5,
                cornerRadius: Double = 0, head: Double = 12,
                start: Point = Point(x: 0, y: 0), end: Point = Point(x: 1, y: 1)) {
        (self.kind, self.sides, self.points, self.innerRatio) = (kind, sides, points, innerRatio)
        (self.cornerRadius, self.head, self.start, self.end) = (cornerRadius, head, start, end)
    }

    /// The tool's options for `kind` before anyone changes them: 5 sides, 5 points at 0.5, radius 0, head 12,
    /// and a line from the box's top-left corner to its bottom-right.
    public static func defaults(_ kind: ShapeKind) -> ShapeSpec { ShapeSpec(kind: kind) }
}
