// TransformRules.swift (transform-tools TT-1 shape, TT-5 body): a layer's box as the transform tools
// see it, and the rules that turn, mirror and scale it. Document y grows downwards, so a positive turn
// is clockwise on screen. Resize by a handle stays BoxMath's.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

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
    /// `degrees` brought into (-180, 180]; a non-finite turn is 0.
    public static func normalized(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return 0 }
        let turn = degrees.truncatingRemainder(dividingBy: 360)
        if turn > 180 { return turn - 360 }
        return turn <= -180 ? turn + 360 : turn
    }

    /// `t` turned clockwise by `degrees` more about its centre, normalized; a non-finite turn is no change.
    public static func rotated(_ t: TransformBox, by degrees: Double) -> TransformBox {
        guard degrees.isFinite else { return t }
        var turned = t
        turned.degrees = normalized(t.degrees + degrees)
        return turned
    }

    /// `t` mirrored about its own centre in `direction`: the mirror flag toggles and the turn is negated,
    /// so the box stays where it is.
    public static func flipped(_ t: TransformBox, _ direction: FlipDirection) -> TransformBox {
        let (flipX, flipY) = direction == .horizontal ? (!t.flipX, t.flipY) : (t.flipX, !t.flipY)
        return TransformBox(box: t.box, degrees: normalized(-t.degrees), flipX: flipX, flipY: flipY)
    }

    /// `t`'s box scaled by `sx` and `sy` about `anchor`, in the box's own frame: the anchor's document
    /// point stays, turn and mirrors included. A factor that isn't a finite number above 0 is no change.
    public static func scaled(_ t: TransformBox, sx: Double, sy: Double, about anchor: BoxAnchor) -> TransformBox {
        guard sx > 0, sy > 0, sx.isFinite, sy.isFinite else { return t }
        let (u, v) = fraction(anchor)
        let kept = matrix(of: t).apply(Point(x: u, y: v))
        let (w, h) = (t.box.width * sx, t.box.height * sy)
        let offset = (turn(t.degrees) * mirror(t)).apply(Point(x: (u - 0.5) * w, y: (v - 0.5) * h))
        let centre = Point(x: kept.x - offset.x, y: kept.y - offset.y)
        let box = Rect(minX: centre.x - w / 2, minY: centre.y - h / 2, maxX: centre.x + w / 2, maxY: centre.y + h / 2)
        return TransformBox(box: box, degrees: t.degrees, flipX: t.flipX, flipY: t.flipY)
    }

    /// The turned box's four corners, clockwise from its top-left (mirrors don't move a box's corners).
    public static func corners(of t: TransformBox) -> [Point] {
        let b = t.box, c = centre(of: t)
        let around = Matrix.translation(x: c.x, y: c.y) * turn(t.degrees) * Matrix.translation(x: -c.x, y: -c.y)
        return [Point(x: b.minX, y: b.minY), Point(x: b.maxX, y: b.minY), Point(x: b.maxX, y: b.maxY), Point(x: b.minX, y: b.maxY)]
            .map(around.apply)
    }

    /// The axis-aligned box around the turned corners; the unturned box when a corner isn't finite.
    public static func bounds(of t: TransformBox) -> Rect { Rect(enclosing: corners(of: t)) ?? t.box }

    /// A document point in the box's unturned, unmirrored frame: to the centre, turned back, mirrored, back.
    public static func local(_ p: Point, in t: TransformBox) -> Point {
        let c = centre(of: t)
        let back = Matrix.translation(x: c.x, y: c.y) * mirror(t) * turn(-t.degrees) * Matrix.translation(x: -c.x, y: -c.y)
        return back.apply(p)
    }

    /// The matrix that takes the unit box to the document: scale, mirror, turn, move.
    public static func matrix(of t: TransformBox) -> Matrix {
        let c = centre(of: t)
        return Matrix.translation(x: c.x, y: c.y) * turn(t.degrees) * mirror(t)
            * Matrix.scale(x: t.box.width, y: t.box.height) * Matrix.translation(x: -0.5, y: -0.5)
    }

    /// Canvas Size: where content `old` wide and high lands (its top-left) in a canvas resized to `new`
    /// about `anchor`: the size change times 0, ½ or 1 on each axis.
    public static func anchoredOrigin(old: (w: Double, h: Double), new: (w: Double, h: Double), _ anchor: BoxAnchor) -> Point {
        let (u, v) = fraction(anchor)
        return Point(x: (new.w - old.w) * u, y: (new.h - old.h) * v)
    }

    /// Where `anchor` sits across and down a box: 0 at the left or top, ½ in the middle, 1 at the right or bottom.
    static func fraction(_ anchor: BoxAnchor) -> (Double, Double) {
        let middle = 0.5
        switch anchor {
        case .topLeft: return (0, 0)
        case .top: return (middle, 0)
        case .topRight: return (1, 0)
        case .left: return (0, middle)
        case .center: return (middle, middle)
        case .right: return (1, middle)
        case .bottomLeft: return (0, 1)
        case .bottom: return (middle, 1)
        case .bottomRight: return (1, 1)
        }
    }

    /// The clockwise turn by `degrees` (document y grows downwards).
    private static func turn(_ degrees: Double) -> Matrix { Matrix.rotation(degrees: degrees) }

    /// `t`'s mirrors: -1 on each flipped axis.
    private static func mirror(_ t: TransformBox) -> Matrix { Matrix.scale(x: t.flipX ? -1 : 1, y: t.flipY ? -1 : 1) }

    /// The centre of `t`'s box, which every turn and mirror keeps.
    private static func centre(of t: TransformBox) -> Point {
        Point(x: (t.box.minX + t.box.maxX) / 2, y: (t.box.minY + t.box.maxY) / 2)
    }
}
