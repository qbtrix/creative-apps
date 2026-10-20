// TransformRules.swift (transform-tools TT-1 shape, TT-5 body): a layer's box as the transform tools
// see it, and the rules that turn, mirror and scale it. Document y grows downwards, so a positive turn
// is clockwise on screen. Stubs return their input until TT-5; resize by a handle stays BoxMath's.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Which way a flip mirrors a box: across its vertical centre line or its horizontal one.
public enum FlipDirection: String, Codable, CaseIterable, Sendable { case horizontal, vertical }

/// One of the nine points of a box a scale or a canvas resize keeps in place.
public enum BoxAnchor: String, Codable, CaseIterable, Sendable {
    case topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight
}

/// A layer as the transform tools see it: its unturned box in document space, its clockwise turn
/// in degrees about the box's centre, and whether it is mirrored on each axis (before the turn).
public struct TransformBox: Hashable, Sendable, Codable {
    public var box: Rect, degrees: Double, flipX: Bool, flipY: Bool

    /// A box with no turn and no mirrors unless given.
    public init(box: Rect, degrees: Double = 0, flipX: Bool = false, flipY: Bool = false) {
        (self.box, self.degrees, self.flipX, self.flipY) = (box, degrees, flipX, flipY)
    }
}

/// Turn, flip and scale rules on a TransformBox, and the points and matrix they describe.
public enum TransformRules {
    /// `degrees` brought into (-180, 180]. Stub: returns its input (TT-5).
    public static func normalized(_ degrees: Double) -> Double { degrees }

    /// `t` turned clockwise by `degrees` more, normalized. Stub: returns its input (TT-5).
    public static func rotated(_ t: TransformBox, by degrees: Double) -> TransformBox { t }

    /// `t` mirrored about its own centre in `direction`, its turn negated. Stub: returns its input (TT-5).
    public static func flipped(_ t: TransformBox, _ direction: FlipDirection) -> TransformBox { t }

    /// `t`'s box scaled by `sx` and `sy` about `anchor`, in the box's own frame. Stub: returns its input (TT-5).
    public static func scaled(_ t: TransformBox, sx: Double, sy: Double, about anchor: BoxAnchor) -> TransformBox { t }

    /// The turned box's four corners, clockwise from its top-left. Stub: the unturned corners (TT-5).
    public static func corners(of t: TransformBox) -> [Point] {
        let b = t.box
        return [Point(x: b.minX, y: b.minY), Point(x: b.maxX, y: b.minY), Point(x: b.maxX, y: b.maxY), Point(x: b.minX, y: b.maxY)]
    }

    /// The axis-aligned box around the turned corners. Stub: the unturned box (TT-5).
    public static func bounds(of t: TransformBox) -> Rect { t.box }

    /// A document point in the box's unturned, unmirrored frame. Stub: returns its input (TT-5).
    public static func local(_ p: Point, in t: TransformBox) -> Point { p }

    /// The matrix that takes the unit box to the document: scale, mirror, turn, move. Stub: identity (TT-5).
    public static func matrix(of t: TransformBox) -> Matrix { .identity }

    /// Canvas Size: where content `old` wide and high lands (its top-left) in a canvas resized to `new`
    /// about `anchor`. Stub: the origin (TT-5).
    public static func anchoredOrigin(old: (w: Double, h: Double), new: (w: Double, h: Double), _ anchor: BoxAnchor) -> Point {
        Point(x: 0, y: 0)
    }
}
