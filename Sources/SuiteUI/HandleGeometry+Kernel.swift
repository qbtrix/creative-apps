// HandleGeometry+Kernel.swift: SuiteHandleGeometry, the live
// HandleGeometryProviding (UC8, SJ10), as an adapter onto the kernel's box
// math (canvas-marks rule 20: no second copy). Hit squares and resize come
// from SuiteKernel's HandleHit and BoxMath; this file adds only what the
// contract asks beyond them: a rotate zone just outside each corner, the
// nearest corner when the rect is smaller than a hit square, and the turn in
// degrees about a centre. Plain math, no SwiftUI (HandleGeometryTests).
import Foundation
import SuiteKernel

/// The live `HandleGeometryProviding`: every handle, edge and rotate zone, where
/// `FakeHandleGeometry` knows corners only.
public struct SuiteHandleGeometry: HandleGeometryProviding {
    public init() {}

    /// The kernel's hit squares for the eight handles, then a `rotateZone` square
    /// diagonally outside each corner's hit square.
    public func handles(around rect: PlaneRect, hitSize: Double, rotateZone: Double) -> [HandleKind: PlaneRect] {
        var out: [HandleKind: PlaneRect] = [:]
        for (handle, square) in BoxMath.handles(of: Self.kernel(rect), size: hitSize) {
            guard let kind = Self.kind(handle) else { continue }
            out[kind] = PlaneRect(x: square.minX, y: square.minY, width: square.width, height: square.height)
        }
        let reach = hitSize / 2 + rotateZone
        for (kind, x, y) in [(HandleKind.rotateTopLeft, rect.minX - reach, rect.minY - reach),
                             (.rotateTopRight, rect.maxX + hitSize / 2, rect.minY - reach),
                             (.rotateBottomRight, rect.maxX + hitSize / 2, rect.maxY + hitSize / 2),
                             (.rotateBottomLeft, rect.minX - reach, rect.maxY + hitSize / 2)] {
            out[kind] = PlaneRect(x: x, y: y, width: rotateZone, height: rotateZone)
        }
        return out
    }

    /// HandleHit within half a hit square, corners winning ties; on a rect smaller than
    /// a hit square only the corners count, so the nearest corner wins; then the rotate zones.
    public func hit(_ point: PlanePoint, around rect: PlaneRect, hitSize: Double, rotateZone: Double) -> HandleKind? {
        let half = hitSize / 2
        let p = Point(x: point.x, y: point.y)
        if let handle = HandleHit.handle(at: p, in: Self.kernel(rect), tolerance: half), let kind = Self.kind(handle) {
            guard rect.extent.width < hitSize || rect.extent.height < hitSize else { return kind }
            let corners: [(HandleKind, Double, Double)] = [(.topLeft, rect.minX, rect.minY), (.topRight, rect.maxX, rect.minY),
                                                           (.bottomRight, rect.maxX, rect.maxY), (.bottomLeft, rect.minX, rect.maxY)]
            let nearest = corners.min { max(abs(point.x - $0.1), abs(point.y - $0.2)) < max(abs(point.x - $1.1), abs(point.y - $1.2)) }
            return nearest?.0 ?? kind
        }
        let zones = handles(around: rect, hitSize: hitSize, rotateZone: rotateZone)
        let order: [HandleKind] = [.rotateTopLeft, .rotateTopRight, .rotateBottomRight, .rotateBottomLeft]
        return order.first { zones[$0]?.contains(point) == true }
    }

    /// BoxMath's resize; ⇧ is the kernel's Shift (the larger relative change on both
    /// sides). The kernel keeps each side at least 1 pt, so a drag past the opposite side
    /// stops at 1, never negative. Rotate zones resize nothing.
    public func resized(_ rect: PlaneRect, handle: HandleKind, by delta: PlanePoint, keepAspect: Bool) -> PlaneRect {
        guard let kernelHandle = Self.kernel(handle) else { return rect }
        let r = BoxMath.resized(Self.kernel(rect), kernelHandle, by: Point(x: delta.x, y: delta.y), modifiers: keepAspect ? .shift : [])
        return PlaneRect(x: r.minX, y: r.minY, width: r.width, height: r.height)
    }

    /// The turn about `center` from `start` to `end` in degrees, clockwise positive with
    /// y down, in (-180, 180]; ⇧ snaps through BoxMath to 15°. 0 when a point sits on the centre.
    public func rotation(from start: PlanePoint, to end: PlanePoint, center: PlanePoint, snap: Bool) -> Double {
        let (sx, sy, ex, ey) = (start.x - center.x, start.y - center.y, end.x - center.x, end.y - center.y)
        guard (sx != 0 || sy != 0), (ex != 0 || ey != 0) else { return 0 }
        var degrees = (atan2(ey, ex) - atan2(sy, sx)) * 180 / Double.pi
        if degrees <= -180 { degrees += 360 }
        if degrees > 180 { degrees -= 360 }
        return BoxMath.snappedDegrees(degrees, modifiers: snap ? .shift : [])
    }

    private static func kernel(_ rect: PlaneRect) -> Rect {
        Rect(minX: rect.minX, minY: rect.minY, maxX: rect.maxX, maxY: rect.maxY)
    }

    private static func kind(_ handle: EditorHandle) -> HandleKind? {
        switch handle {
        case .topLeft: .topLeft
        case .top: .top
        case .topRight: .topRight
        case .right: .right
        case .bottomRight: .bottomRight
        case .bottom: .bottom
        case .bottomLeft: .bottomLeft
        case .left: .left
        case .inside, .rotate: nil
        }
    }

    private static func kernel(_ kind: HandleKind) -> EditorHandle? {
        EditorHandle.allCases.first { Self.kind($0) == kind }
    }
}
