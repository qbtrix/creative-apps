// Live/LiveTransform+Kernel.swift: PV-7's free transform on SuiteKernel
// (adopt-kernel-transform AT-p1). The handle under the pointer is
// `HandleHit`'s, a side or corner drag is `BoxMath.resized` with Photo's
// Shift and Option as `EditModifiers`, a turn goes through
// `BoxMath.snappedDegrees`. The box the kernel sees is the draft's box scaled
// about its top-left and moved; a turn is about that box's centre, so points
// are turned back into the box's own frame first. Applying and flipping pixels
// are not built yet: they refuse with PV-7's help, which stays the tool's
// unavailable help. Linux-safe; libm comes from Glibc/Musl/Darwin as in
// PhotoStraighten.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif
import CoreRaster
import SuiteKernel

struct KernelTransform: LayerTransforming {
    let not = NotBuilt(feature: "PV-7")
    var unavailableHelp: String? { not.help }

    func handle(at point: Mask.Point, in draft: TransformDraft, tolerance: Double) -> TransformHandle? {
        let box = KernelBox(draft)
        return HandleHit.handle(at: box.local(point), in: box.rect, tolerance: tolerance)
    }

    func dragged(_ draft: TransformDraft, handle: TransformHandle, from start: Mask.Point, to point: Mask.Point,
                 modifiers: DragModifiers) -> TransformDraft {
        let box = KernelBox(draft)
        var next = draft
        switch handle {
        case .inside:
            let (dx, dy) = (point.x - start.x, point.y - start.y)
            guard dx.isFinite, dy.isFinite else { return draft }
            next.transform.dx += dx
            next.transform.dy += dy
        case .rotate:
            let c = box.centre
            var turn = (atan2(point.y - c.y, point.x - c.x) - atan2(start.y - c.y, start.x - c.x)) * 180 / .pi
            guard turn.isFinite else { return draft }
            turn -= 360 * (turn / 360).rounded()
            next.transform.degrees = BoxMath.snappedDegrees(draft.transform.degrees + turn, modifiers: kernel(modifiers))
        default:
            let (a, b) = (box.local(start), box.local(point))
            let delta = Point(x: b.x - a.x, y: b.y - a.y)
            next.transform = box.transform(for: BoxMath.resized(box.rect, handle, by: delta, modifiers: kernel(modifiers)))
        }
        return next
    }

    func corners(of draft: TransformDraft) -> [Mask.Point] {
        let box = KernelBox(draft), r = box.rect
        return [(r.minX, r.minY), (r.maxX, r.minY), (r.maxX, r.maxY), (r.minX, r.maxY)].map { x, y in
            let p = box.turned(Point(x: x, y: y), 1)
            return Mask.Point(x: p.x, y: p.y)
        }
    }

    func applied(_ draft: TransformDraft, to content: PlacedPixels) throws -> PlacedPixels { throw not.refuse() }
    func flipped(_ content: PlacedPixels, _ axis: FlipAxis) throws -> PlacedPixels { throw not.refuse() }

    /// Photo's drag modifiers as the kernel's.
    private func kernel(_ modifiers: DragModifiers) -> EditModifiers {
        var out: EditModifiers = []
        if modifiers.contains(.shift) { out.insert(.shift) }
        if modifiers.contains(.option) { out.insert(.option) }
        return out
    }
}

/// A draft's box as the kernel sees it: scaled about its top-left and moved,
/// the turn kept apart (about the box's centre) to map points in and out.
private struct KernelBox {
    let draft: TransformDraft
    let rect: Rect
    let radians: Double

    init(_ draft: TransformDraft) {
        let b = draft.box, t = draft.transform
        let (x, y) = (Double(b.x) + t.dx, Double(b.y) + t.dy)
        self.draft = draft
        rect = Rect(minX: x, minY: y, maxX: x + Double(b.width) * t.scaleX, maxY: y + Double(b.height) * t.scaleY)
        radians = t.degrees * .pi / 180
    }

    var centre: Point { Point(x: (rect.minX + rect.maxX) / 2, y: (rect.minY + rect.maxY) / 2) }

    /// `p` turned about the centre by the turn (`sign` 1) or back (`sign` -1).
    func turned(_ p: Point, _ sign: Double) -> Point {
        guard radians != 0 else { return p }
        let c = centre, (s, k) = (sin(sign * radians), cos(sign * radians))
        let (x, y) = (p.x - c.x, p.y - c.y)
        return Point(x: c.x + x * k - y * s, y: c.y + x * s + y * k)
    }

    /// A canvas point in the box's own (unturned) frame.
    func local(_ p: Mask.Point) -> Point { turned(Point(x: p.x, y: p.y), -1) }

    /// The transform that makes the box `resized` in its own frame, moved so
    /// the side `resized` kept stays where it was on the canvas.
    func transform(for resized: Rect) -> LayerTransform {
        let b = draft.box
        var t = draft.transform
        let newCentre = Point(x: (resized.minX + resized.maxX) / 2, y: (resized.minY + resized.maxY) / 2)
        let placed = turned(newCentre, 1)
        if b.width > 0 { t.scaleX = resized.width / Double(b.width) }
        if b.height > 0 { t.scaleY = resized.height / Double(b.height) }
        t.dx = resized.minX + placed.x - newCentre.x - Double(b.x)
        t.dy = resized.minY + placed.y - newCentre.y - Double(b.y)
        return t
    }
}
