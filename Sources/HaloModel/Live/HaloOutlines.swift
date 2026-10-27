// Live/HaloOutlines.swift (VP-4a): the outline a solid (its rectangle) or a
// shape (its ellipse, or its spec's path, HS-5) covers in composition space, for VP-4b's
// LiveFrameRendering. An item drawn at translate + positive scale only keeps
// its world box, so the renderer uses CoreRaster's exact Mask.rectangle /
// Mask.ellipse; any other matrix maps the outline's points through
// HaloMatrix.apply and flattens it with FlareCore's Path to a polygon for
// Mask.polygon. A non-finite or degenerate outline is nil: it draws nothing.
// A shape's stroke (HK-5) is the outline of its trimmed, dashed path, its
// trim sampled at the frame from the Trim tracks. Linux-safe.
import CoreRaster
import FlareCore
import SuiteKernel

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
        case .shape:
            if let spec = item.shape { outline(spec, bounds: item.bounds, matrix: item.matrix, scale: scale) }
            else { outline(.ellipse, bounds: item.bounds, matrix: item.matrix, scale: scale) }
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

    /// A shape layer's `spec` drawn in `bounds` (layer space) through the
    /// kernel's ShapeRules, every point mapped through `matrix`, flattened at
    /// 0.25 / `scale` to a polygon. Only closed subpaths fill: an arrow fills
    /// its head, not its shaft, and several join into one even-odd polygon.
    /// Nil for a spec ShapeRules refuses, a line or a non-finite point.
    static func outline(_ spec: ShapeSpec, bounds r: HaloLayerRect, matrix m: HaloMatrix, scale: Double = 1) -> HaloOutline? {
        guard isFinite(m), m.determinant != 0, scale.isFinite, scale > 0,
              let path = try? ShapeRules.path(spec, in: Rect(minX: r.x, minY: r.y, maxX: r.x + r.width, maxY: r.y + r.height)),
              let lines = try? path.transformed(by: m).flattened(tolerance: 0.25 / scale)
        else { return nil }
        let closed = lines.filter { $0.count >= 4 && $0.first == $0.last }
        guard closed.count == 1, var points = closed.first else { return polygon(joining: closed) }
        points.removeLast()
        guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        return .polygon(points)
    }

    /// `layer`'s stroke with its trim at frame `f` (HK-5): with a stored trim
    /// or any trim track, each of Trim Start, End and Offset is its track
    /// sampled at `f` (the stored value with no track). Nil off shape layers.
    static func stroke(of layer: HaloLayer, in c: HaloComposition, at f: Int) -> VectorStroke? {
        guard layer.kind == .shape, var stroke = layer.stroke else { return nil }
        guard stroke.trim != nil || HaloProperty.trims.contains(where: { layer.tracks[$0.rawValue] != nil })
        else { return stroke }
        func v(_ p: HaloProperty) -> Double { HaloKeyRules.value(p, of: layer, in: c, at: f) }
        stroke.trim = StrokeTrim(
            start: v(.trimStart), end: v(.trimEnd), offset: v(.trimOffset), mode: stroke.trim?.mode ?? .together)
        return stroke
    }

    /// A shape item's stroke as the outline of its painted path (trimmed,
    /// then dashed: StrokeRules.paintedPath) through FlareCore's
    /// `Path.outlined`, in layer space, then mapped through the matrix and
    /// flattened at 0.25 / `scale`. Nil with no stroke, nothing painted, or
    /// anything refused or non-finite.
    static func strokeOutline(of item: HaloDrawItem, scale: Double = 1) -> HaloOutline? {
        let r = item.bounds, m = item.matrix
        guard item.kind == .shape, let stroke = item.stroke, isFinite(m), m.determinant != 0, scale.isFinite, scale > 0,
              [r.x, r.y, r.width, r.height].allSatisfy(\.isFinite)
        else { return nil }
        let box = Rect(minX: r.x, minY: r.y, maxX: r.x + r.width, maxY: r.y + r.height)
        let shape: FlareCore.Path?
        if let spec = item.shape { shape = try? ShapeRules.path(spec, in: box) }
        else { shape = path(.ellipse, bounds: r, matrix: .identity) }
        let layerTolerance = 0.25 / (scale * abs(m.determinant).squareRoot())
        guard let shape, let painted = try? StrokeRules.paintedPath(shape, stroke), !painted.elements.isEmpty,
              let outline = try? painted.outlined(
                width: stroke.width, join: stroke.join, cap: stroke.cap, miterLimit: 4, tolerance: layerTolerance),
              let rings = try? outline.transformed(by: m).flattened(tolerance: 0.25 / scale)
        else { return nil }
        return polygon(joining: rings)
    }

    /// `rings` as one even-odd polygon: each ring is entered from the first
    /// ring's start and left back to it, so every bridge edge is crossed
    /// twice and cancels. Nil with no ring of 3 points or a non-finite point.
    static func polygon(joining rings: [[HaloPoint]]) -> HaloOutline? {
        let closed = rings.map { $0.count > 1 && $0.first == $0.last ? Array($0.dropLast()) : $0 }.filter { $0.count >= 3 }
        guard let anchor = closed.first?.first else { return nil }
        var points: [HaloPoint] = []
        for ring in closed {
            guard let start = ring.first else { continue }
            points += ring + [start, anchor]
        }
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
