// HandleGeometryProviding.swift: UC8 (SJ10, SP5), the selection handles' hit
// rects, resize and rotate math, and FakeHandleGeometry, which knows corners
// only on purpose (the live rule, SuiteHandleGeometry, is CM-2). Foundation
// only; verbatim from blueprint section 5.2.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum HandleKind: String, Sendable, CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    /// The rotate zones, one just outside each corner (docs/design.md, Stage marks).
    case rotateTopLeft, rotateTopRight, rotateBottomRight, rotateBottomLeft
}

public protocol HandleGeometryProviding: Sendable {
    /// Each handle's hit rect in view points around `rect` (view points at the current zoom). The hit size
    /// is `SuiteSize.selectionHandleHit` (12 pt) at every zoom; a rotate zone (`rotateZone`, 16 pt) sits just
    /// outside each corner.
    /// Each rotate zone's rect bounds its quarter ring of `rotateZone` points.
    func handles(around rect: PlaneRect, hitSize: Double, rotateZone: Double) -> [HandleKind: PlaneRect]
    /// The handle under `point`, corners before edges before rotate zones; nil when none. Where hit squares
    /// overlap (a rect smaller than the hit size) the corner nearest the point wins.
    func hit(_ point: PlanePoint, around rect: PlaneRect, hitSize: Double, rotateZone: Double) -> HandleKind?
    /// `rect` after dragging `handle` by `delta`, the opposite side fixed; `keepAspect` (⇧) scales evenly.
    func resized(_ rect: PlaneRect, handle: HandleKind, by delta: PlanePoint, keepAspect: Bool) -> PlaneRect
    /// Degrees turned about `center` from `start` to `end`, clockwise positive (y-down), ⇧ snaps to 15°.
    func rotation(from start: PlanePoint, to end: PlanePoint, center: PlanePoint, snap: Bool) -> Double
}

/// Corner handles only; edges and rotate zones are never hit, and overlapping squares pick any one of them.
/// Enough to draw handles, not for SJ10.
public struct FakeHandleGeometry: HandleGeometryProviding {
    public init() {}
    private func square(_ p: PlanePoint, _ s: Double) -> PlaneRect { PlaneRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s) }
    public func handles(around rect: PlaneRect, hitSize: Double, rotateZone: Double) -> [HandleKind: PlaneRect] {
        [.topLeft: square(rect.origin, hitSize),
         .topRight: square(PlanePoint(x: rect.maxX, y: rect.minY), hitSize),
         .bottomRight: square(PlanePoint(x: rect.maxX, y: rect.maxY), hitSize),
         .bottomLeft: square(PlanePoint(x: rect.minX, y: rect.maxY), hitSize)]
    }
    public func hit(_ point: PlanePoint, around rect: PlaneRect, hitSize: Double, rotateZone: Double) -> HandleKind? {
        handles(around: rect, hitSize: hitSize, rotateZone: rotateZone).first { $0.value.contains(point) }?.key
    }
    public func resized(_ rect: PlaneRect, handle: HandleKind, by delta: PlanePoint, keepAspect: Bool) -> PlaneRect {
        guard handle == .bottomRight else { return rect }
        return PlaneRect(x: rect.minX, y: rect.minY, width: max(rect.extent.width + delta.x, 0), height: max(rect.extent.height + delta.y, 0))
    }
    public func rotation(from start: PlanePoint, to end: PlanePoint, center: PlanePoint, snap: Bool) -> Double { 0 }
}
