// Live/HaloOutlines.swift (VP-4a): the outline a solid (its rectangle) or a
// shape (its ellipse) covers in composition space, for VP-4b's
// LiveFrameRendering. An item drawn at translate + positive scale only keeps
// its world box, so the renderer uses CoreRaster's exact Mask.rectangle /
// Mask.ellipse; any other matrix maps the outline's points through
// HaloMatrix.apply and flattens it with FlareCore's Path to a polygon for
// Mask.polygon. A non-finite or degenerate outline is nil: it draws nothing.
// Linux-safe.
import CoreRaster
import FlareCore

/// The two outlines an item can have.
enum HaloOutlineShape: Sendable, Hashable {
    case rectangle, ellipse
}

/// What one item covers in composition space.
enum HaloOutline: Sendable, Hashable {
    /// The axis-aligned world box of a rectangle.
    case rectangle(HaloLayerRect)
    /// The axis-aligned world box of an ellipse.
    case ellipse(HaloLayerRect)
    /// The flattened outline through the matrix, closed implicitly.
    case polygon([HaloPoint])

    /// The coverage on a `width` × `height` frame, composition space scaled
    /// by (`scaleX`, `scaleY`) into pixels. Throws what CoreRaster's Mask throws.
    func mask(width: Int, height: Int, scaleX: Double, scaleY: Double) throws -> Mask {
        switch self {
        case .rectangle(let r):
            return try Mask.rectangle(
                width: width, height: height,
                x: r.x * scaleX, y: r.y * scaleY, w: r.width * scaleX, h: r.height * scaleY)
        case .ellipse(let r):
            return try Mask.ellipse(
                width: width, height: height,
                centerX: (r.x + r.width / 2) * scaleX, centerY: (r.y + r.height / 2) * scaleY,
                radiusX: r.width / 2 * scaleX, radiusY: r.height / 2 * scaleY)
        case .polygon(let points):
            return try Mask.polygon(
                width: width, height: height,
                points: points.map { Mask.Point(x: $0.x * scaleX, y: $0.y * scaleY) })
        }
    }
}

enum HaloOutlines {
    /// The cubic control-point distance for a quarter circle of radius 1.
    static let kappa = 0.5523

    /// A unit circle as four cubics from (1, 0), one per quadrant:
    /// (control1, control2, to). Later: creative-core #182's
    /// `Path.ellipse(in:)` replaces this table and `path(_:bounds:matrix:)`'s
    /// ellipse case in one function swap.
    private static let unitCircle: [(Double, Double, Double, Double, Double, Double)] = [
        (1, kappa, kappa, 1, 0, 1),
        (-kappa, 1, -1, kappa, -1, 0),
        (-1, -kappa, -kappa, -1, 0, -1),
        (kappa, -1, 1, -kappa, 1, 0),
    ]

    /// Translate and positive scale only, every entry finite.
    static func isAxisAligned(_ m: HaloMatrix) -> Bool {
        isFinite(m) && m.b == 0 && m.c == 0 && m.a > 0 && m.d > 0
    }

    /// The outline of a solid (rectangle) or a shape (ellipse); nil for text and nulls.
    static func outline(of item: HaloDrawItem, scale: Double = 1) -> HaloOutline? {
        switch item.kind {
        case .solid: outline(.rectangle, bounds: item.bounds, matrix: item.matrix, scale: scale)
        case .shape: outline(.ellipse, bounds: item.bounds, matrix: item.matrix, scale: scale)
        case .text, .null: nil
        }
    }

    /// `shape` of `bounds` (layer space) at `matrix`. A rotated, skewed or
    /// mirrored matrix flattens at 0.25 / `scale` so the polygon stays within a
    /// quarter pixel at the render scale. Nil when anything is non-finite, the
    /// box is empty or the matrix is singular.
    static func outline(
        _ shape: HaloOutlineShape, bounds r: HaloLayerRect, matrix m: HaloMatrix, scale: Double = 1
    ) -> HaloOutline? {
        guard isFinite(m), m.determinant != 0, scale.isFinite, scale > 0,
              [r.x, r.y, r.width, r.height].allSatisfy(\.isFinite), r.width > 0, r.height > 0
        else { return nil }
        if isAxisAligned(m) {
            let world = HaloLayerRect(
                x: m.a * r.x + m.tx, y: m.d * r.y + m.ty, width: m.a * r.width, height: m.d * r.height)
            guard [world.x, world.y, world.width, world.height].allSatisfy(\.isFinite) else { return nil }
            return shape == .rectangle ? .rectangle(world) : .ellipse(world)
        }
        guard let lines = try? path(shape, bounds: r, matrix: m).flattened(tolerance: 0.25 / scale),
              var points = lines.first, points.count >= 3
        else { return nil }
        if points.first == points.last { points.removeLast() }
        guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        return .polygon(points)
    }

    /// The closed path of `shape` in composition space: each point mapped
    /// through `matrix` (an affine map keeps a cubic a cubic).
    static func path(_ shape: HaloOutlineShape, bounds r: HaloLayerRect, matrix m: HaloMatrix) -> FlareCore.Path {
        switch shape {
        case .rectangle:
            let corners = [(r.x, r.y), (r.x + r.width, r.y), (r.x + r.width, r.y + r.height), (r.x, r.y + r.height)]
            return FlareCore.Path(polyline: corners.map { m.apply(HaloPoint(x: $0.0, y: $0.1)) }, closed: true)
        case .ellipse:
            let rx = r.width / 2, ry = r.height / 2, cx = r.x + rx, cy = r.y + ry
            func at(_ ux: Double, _ uy: Double) -> HaloPoint { m.apply(HaloPoint(x: cx + ux * rx, y: cy + uy * ry)) }
            var elements: [PathElement] = [.move(to: at(1, 0))]
            for q in unitCircle {
                elements.append(.cubic(control1: at(q.0, q.1), control2: at(q.2, q.3), to: at(q.4, q.5)))
            }
            elements.append(.close)
            return FlareCore.Path(elements: elements)
        }
    }

    private static func isFinite(_ m: HaloMatrix) -> Bool {
        [m.a, m.b, m.c, m.d, m.tx, m.ty].allSatisfy(\.isFinite)
    }
}
