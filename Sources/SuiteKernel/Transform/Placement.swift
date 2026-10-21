// Transform/Placement.swift (anchor-parenting AN-1 stubs, AN-3 bodies): a
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
    /// nothing moves on screen: (x, y) += R·S·(p − anchor). AN-3 builds it;
    /// the stub returns the placement unchanged.
    public func movingAnchor(to p: Point) -> Placement {
        self
    }

    /// One of the nine points of `box` (layer space), for the picker and
    /// `{at:}`. AN-3 builds it; the stub answers the box's top-left corner.
    public static func anchorPoint(at a: BoxAnchor, in box: Rect) -> Point {
        Point(x: box.minX, y: box.minY)
    }
}
