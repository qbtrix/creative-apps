// Transform/Placement.swift (anchor-parenting AN-1 shape, AN-3 bodies): a
// layer's place in its parent. The kernel's geometry is FlareCore's (editor-kernel
// design decision 2), and FlareCore's `Transform` already holds position,
// scale, clockwise degrees and the anchor in the layer's own space, with the
// matrix T(x, y) · R(rotation) · S(scaleX, scaleY) · T(−anchorX, −anchorY):
// Halo's `localMatrix` rule. So `Placement` is that type under the kernel's
// name, and this file adds only the anchor rules every app shares.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// A layer's place in its parent: FlareCore's `Transform` (x, y, scaleX, scaleY,
/// clockwise `rotation` in degrees, anchorX, anchorY; `identity`; `matrix`).
public typealias Placement = FlareCore.Transform

extension Placement {
    /// The same layer with its anchor at `p` (layer space) and x, y moved so
    /// nothing moves on screen: (x, y) += R·S·(p − anchor), Halo's
    /// keep-in-place step. A point that isn't finite is no change.
    public func movingAnchor(to p: Point) -> Placement {
        guard p.x.isFinite, p.y.isFinite else { return self }
        let offset = Point(x: p.x - anchorX, y: p.y - anchorY)
        // R·S with no translation: where the offset lands once scaled and turned.
        let turned = (Matrix.rotation(degrees: rotation) * Matrix.scale(x: scaleX, y: scaleY)).apply(offset)
        var moved = self
        (moved.x, moved.y, moved.anchorX, moved.anchorY) = (x + turned.x, y + turned.y, p.x, p.y)
        return moved
    }

    /// One of the nine points of `box` (layer space), for the picker and
    /// `{at:}`: the corners, the edge middles and the centre.
    public static func anchorPoint(at a: BoxAnchor, in box: Rect) -> Point {
        let (u, v) = TransformRules.fraction(a)
        return Point(x: box.minX + (box.maxX - box.minX) * u, y: box.minY + (box.maxY - box.minY) * v)
    }
}
