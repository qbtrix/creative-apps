// Live/LiveTransform+Kernel.swift: PV-7's free transform on SuiteKernel
// (adopt-kernel-transform AT-p1, transform PT-4). The handle under the pointer
// is `HandleHit`'s, a side or corner drag is `BoxMath.resized` with Photo's
// Shift and Option as `EditModifiers`, a turn goes through
// `BoxMath.snappedDegrees`. The box the kernel sees is the draft's box scaled
// about its top-left and moved, turned about its centre; points reach the
// box's own frame through `TransformRules.local` and leave it through
// `TransformRules.matrix`. Commit resamples once with CoreRaster's
// `transformed` (lanczos3) through `matrix`, the one that takes the old box to
// the new one; a drag frame draws each canvas region through the same matrix
// (PhotoRenderRoute.swift); a flip is CoreRaster's exact `flipped`.
// Linux-safe; libm comes from Glibc/Musl/Darwin as in PhotoStraighten.
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
    var unavailableHelp: String? { nil }

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
        TransformRules.corners(of: KernelBox(draft).kernel).map { Mask.Point(x: $0.x, y: $0.y) }
    }

    /// One lanczos3 resample of `content` through `matrix`, into the
    /// transformed bounds (whole pixels around them). The identity is
    /// `content` itself.
    func applied(_ draft: TransformDraft, to content: PlacedPixels) throws -> PlacedPixels {
        guard draft.transform != .identity else { return content }
        let (x0, y0, x1, y1) = try Self.pixelBounds(TransformRules.bounds(of: KernelBox(draft).kernel))
        var affine = try matrix(draft, origin: (content.x, content.y))
        (affine.tx, affine.ty) = (affine.tx - Double(x0), affine.ty - Double(y0))  // to the output's top-left
        let out = try content.pixels.flattened().transformed(affine, width: x1 - x0, height: y1 - y0, filter: .lanczos3)
        return PlacedPixels(pixels: TiledPixels(out), x: x0, y: y0)
    }

    /// Layer pixel to canvas, to the old box's unit square, to the new box: the matrix that takes the draft's
    /// box to its transformed box, for a layer whose top-left is at `origin`.
    func matrix(_ draft: TransformDraft, origin: (x: Int, y: Int)) throws -> AffineMatrix {
        let b = draft.box
        let before = TransformBox(box: Rect(minX: Double(b.x), minY: Double(b.y),
                                            maxX: Double(b.x + b.width), maxY: Double(b.y + b.height)))
        let (forward, back) = try (TransformRules.matrix(of: KernelBox(draft).kernel), TransformRules.matrix(of: before).inverted())
        func mapped(_ x: Double, _ y: Double) -> Point {
            forward.apply(back.apply(Point(x: x + Double(origin.x), y: y + Double(origin.y))))
        }
        let (o, i, j) = (mapped(0, 0), mapped(1, 0), mapped(0, 1))
        return AffineMatrix(a: i.x - o.x, b: i.y - o.y, c: j.x - o.x, d: j.y - o.y, tx: o.x, ty: o.y)
    }

    /// `content` mirrored in place by CoreRaster's exact `flipped`.
    func flipped(_ content: PlacedPixels, _ axis: FlipAxis) throws -> PlacedPixels {
        let across: CoreRaster.FlipAxis = axis == .horizontal ? .horizontal : .vertical
        let out = try content.pixels.flattened().flipped(across)
        return PlacedPixels(pixels: TiledPixels(out), x: content.x, y: content.y)
    }

    /// The whole pixels around `r`: its edges out to the next pixel, an edge
    /// within 1e-6 of a whole pixel kept on it. Throws for an edge that isn't
    /// finite or is too far out to be a canvas, or an empty box.
    private static func pixelBounds(_ r: Rect) throws -> (Int, Int, Int, Int) {
        let limit = 1e9
        let edges = [r.minX, r.minY, r.maxX, r.maxY]
        guard edges.allSatisfy({ $0.isFinite && abs($0) < limit }) else {
            throw RasterError.invalid("the transformed box is out of range; undo the last scale or move")
        }
        func snapped(_ v: Double) -> Double { abs(v - v.rounded()) < 1e-6 ? v.rounded() : v }
        let (x0, y0) = (Int(snapped(r.minX).rounded(.down)), Int(snapped(r.minY).rounded(.down)))
        let (x1, y1) = (Int(snapped(r.maxX).rounded(.up)), Int(snapped(r.maxY).rounded(.up)))
        guard x1 > x0, y1 > y0 else { throw RasterError.invalid("the transformed box is empty; scale it up first") }
        return (x0, y0, x1, y1)
    }

    /// Photo's drag modifiers as the kernel's.
    private func kernel(_ modifiers: DragModifiers) -> EditModifiers {
        var out: EditModifiers = []
        if modifiers.contains(.shift) { out.insert(.shift) }
        if modifiers.contains(.option) { out.insert(.option) }
        return out
    }
}

/// A draft's box as the kernel sees it: scaled about its top-left and moved,
/// turned about its centre. Points go into its own frame by
/// `TransformRules.local` and back out by `TransformRules.matrix`.
private struct KernelBox {
    let draft: TransformDraft
    let rect: Rect
    let kernel: TransformBox

    init(_ draft: TransformDraft) {
        let b = draft.box, t = draft.transform
        let (x, y) = (Double(b.x) + t.dx, Double(b.y) + t.dy)
        self.draft = draft
        rect = Rect(minX: x, minY: y, maxX: x + Double(b.width) * t.scaleX, maxY: y + Double(b.height) * t.scaleY)
        kernel = TransformBox(box: rect, degrees: t.degrees)
    }

    var centre: Point { Point(x: (rect.minX + rect.maxX) / 2, y: (rect.minY + rect.maxY) / 2) }

    /// A canvas point in the box's own (unturned) frame.
    func local(_ p: Mask.Point) -> Point { TransformRules.local(Point(x: p.x, y: p.y), in: kernel) }

    /// `p` in the box's own frame, turned out onto the canvas about the
    /// centre: the matrix of a unit box on that centre with the same turn.
    func placed(_ p: Point) -> Point {
        let c = centre
        let unit = TransformBox(box: Rect(minX: c.x - 0.5, minY: c.y - 0.5, maxX: c.x + 0.5, maxY: c.y + 0.5),
                                degrees: kernel.degrees)
        return TransformRules.matrix(of: unit).apply(Point(x: p.x - c.x + 0.5, y: p.y - c.y + 0.5))
    }

    /// The transform that makes the box `resized` in its own frame, moved so
    /// the side `resized` kept stays where it was on the canvas.
    func transform(for resized: Rect) -> LayerTransform {
        let b = draft.box
        var t = draft.transform
        let newCentre = Point(x: (resized.minX + resized.maxX) / 2, y: (resized.minY + resized.maxY) / 2)
        let placed = placed(newCentre)
        if b.width > 0 { t.scaleX = resized.width / Double(b.width) }
        if b.height > 0 { t.scaleY = resized.height / Double(b.height) }
        t.dx = resized.minX + placed.x - newCentre.x - Double(b.x)
        t.dy = resized.minY + placed.y - newCentre.y - Double(b.y)
        return t
    }
}
