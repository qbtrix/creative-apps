// BoxGestureMath.swift: the box-gesture math behind `ShapeBuilding.boxResult` (docs/blueprints/flare.md, 6.3), shared
// by the fake and live shapes so the two can't drift. Move adds to x, y; Scale stretches about the handle opposite
// the grip in the layer's own axes, or works on the world box for a layer turned off a multiple of 90° (#560, #625);
// Rotate turns about the box center. The layers' drawn items come from the `StageDrawList` the caller passes. The
// handles are the kernel's `EditorHandle` ring (BoxGestureMath+Kernel.swift).
import FlareCore
import SuiteKernel

public enum BoxGestureMath {
    /// What each picked layer's x, y, scaleX, scaleY and rotation become for `gesture` on `box`; a layer the gesture
    /// would leave 0 wide (or tall) or non-finite is left out. `list` is the stage's draw list for this frame.
    public static func result(_ gesture: BoxGesture, layers: [String], document: Document, sceneID: String,
                              frame: Int, box: Rect, list: StageDrawList) -> [String: [String: Double]] {
        var result: [String: [String: Double]] = [:]
        for layer in document.layers(of: .scene(sceneID)) ?? [] where layers.contains(layer.id) {
            let t = layer.placement(at: Double(frame)).transform
            var values: [String: Double]
            switch gesture {
            case .move(let dx, let dy): values = ["x": t.x + dx, "y": t.y + dy]
            case .scale(let h, let to):
                if let oblique = obliqueScale(h, to: to, layer: layer, t: t, list: list, box: box) {
                    values = oblique
                    break
                }
                let handle = editorHandle(h), grip = spot(handle, on: box), fixed = spot(opposite(handle), on: box)
                // An edge handle drags one world axis; drop the other part of the pointer.
                let pointer = Point(x: movesOnlyY(handle) ? grip.x : to.x, y: movesOnlyX(handle) ? grip.y : to.y)
                // Work in the layer's own axes, so a rotated layer stretches along its sides about the fixed handle.
                let (turn, back) = (Matrix.rotation(degrees: t.rotation), Matrix.rotation(degrees: -t.rotation))
                let from = back.apply(Point(x: grip.x - fixed.x, y: grip.y - fixed.y))
                let onto = back.apply(Point(x: pointer.x - fixed.x, y: pointer.y - fixed.y))
                // An edge stretches only the local axis nearest its world axis.
                let alongX = abs(turn.a) >= abs(turn.b), edge = !handle.isCorner
                let keepX = edge && movesOnlyY(handle) == alongX, keepY = edge && movesOnlyX(handle) == alongX
                let sx = keepX ? 1 : ratio(onto.x, from.x), sy = keepY ? 1 : ratio(onto.y, from.y)
                // Square to the world, a zero axis leaves the box 0 wide (or tall), and every later drag reads that
                // side as 0 and can't grow it: leave the layer as it was, as for 0 x 0 below (#688). A drop within
                // rounding of the opposite line (the viewport maps one there at 70%) rounds the box to 0 too (#698).
                if sx == 0 || sy == 0 || (!keepX && from.x != 0 && abs(onto.x) < lineTolerance)
                    || (!keepY && from.y != 0 && abs(onto.y) < lineTolerance) { continue }
                let o = back.apply(Point(x: t.x - fixed.x, y: t.y - fixed.y))
                let p = turn.apply(Point(x: o.x * sx, y: o.y * sy))
                values = ["x": fixed.x + p.x, "y": fixed.y + p.y, "scaleX": t.scaleX * sx, "scaleY": t.scaleY * sy]
            case .rotate(let degrees):
                let c = Point(x: (box.minX + box.maxX) / 2, y: (box.minY + box.maxY) / 2)
                let p = Matrix.rotation(degrees: degrees).apply(Point(x: t.x - c.x, y: t.y - c.y))
                values = ["x": c.x + p.x, "y": c.y + p.y, "rotation": t.rotation + degrees]
            }
            // A corner dropped on the opposite corner would leave the layer 0 x 0, and no later drag could grow it:
            // leave the layer as it was, as an edge dropped on the opposite edge keeps one axis (#655, #682).
            if values["scaleX"] == 0, values["scaleY"] == 0 { continue }
            if values.values.allSatisfy(\.isFinite) { result[layer.id] = values }
        }
        return result
    }

    /// Scale on a layer turned off a multiple of 90° (#560, #625). The stage shows the layer's world box, so the
    /// gesture works on that box: its handle opposite the grip stays put, and the layer's own scaleX/scaleY are picked so
    /// its new world box lands as near as it can to the one the pointer asks for. An edge handle scales the layer evenly,
    /// so its edge follows the pointer exactly along its axis. A turned box can't take every shape (at 45° it is always
    /// square), so a corner keeps each local stretch between the two world stretches: it never blows up near 45° or
    /// flattens the layer. A grip dragged through the fixed handle mirrors the layer, as at 0° (#655). Nil when the
    /// layer is square to the world.
    private static func obliqueScale(_ h: Int, to: Point, layer: Layer, t: Transform, list: StageDrawList,
                                     box: Rect) -> [String: Double]? {
        let quarter = t.rotation.remainder(dividingBy: 90)
        // A layer an edge drop flattened (#673) has a zero scale, and its matrix can't be inverted (#679). Invert it as
        // if that scale were 1 instead: the content's coordinate on the zero axis comes back as 0, and every use below
        // scales it by 0 again, so the box math is unchanged.
        let open = Transform(x: t.x, y: t.y, scaleX: t.scaleX == 0 ? 1 : t.scaleX, scaleY: t.scaleY == 0 ? 1 : t.scaleY,
                             rotation: t.rotation)
        guard quarter.isFinite, abs(quarter) > 1e-9, let back = try? open.matrix.inverted() else { return nil }
        // The layer's content in its own space: each drawn item's box (stroke included), as the hit tester bounds it.
        var points: [Point] = []
        for item in list.items where item.address.layerID == layer.id && !item.isText {
            guard let path = item.path.bounds else { continue }
            let width = item.stroke?.width ?? 0, half = width.isFinite ? max(width, 0) / 2 : 0
            let r = Rect(minX: path.minX - half, minY: path.minY - half, maxX: path.maxX + half, maxY: path.maxY + half)
            points += corners(r).map { (back * item.transform).apply($0) }
        }
        guard let local = Rect(enclosing: points), let own = Rect(enclosing: points.map(t.matrix.apply)) else { return nil }
        let handle = editorHandle(h), grip = spot(handle, on: box), fixed = spot(opposite(handle), on: box)
        // The signed world stretch the pointer asks of the box about its fixed handle; an edge leaves its other axis
        // at 1. Below 0 the grip has crossed the fixed handle and the box mirrors on that axis (#655).
        let wx = movesOnlyY(handle) ? 1 : ratio(to.x - fixed.x, grip.x - fixed.x)
        let wy = movesOnlyX(handle) ? 1 : ratio(to.y - fixed.y, grip.y - fixed.y)
        let (kx, ky) = (abs(wx), abs(wy))
        // The world box's size from the local stretch f: width = a·f, height = b·f.
        let turn = Matrix.rotation(degrees: t.rotation), (c, s) = (abs(turn.a), abs(turn.b))
        let (u, v) = (abs(t.scaleX) * local.width, abs(t.scaleY) * local.height)
        let a = (c * u, s * v), b = (s * u, c * v)
        // The local axis nearest world x; the other is nearest world y.
        let alongX = c >= s
        var f = !handle.isCorner ? (x: movesOnlyY(handle) ? ky : kx, y: movesOnlyY(handle) ? ky : kx)
            : fit(a, b, to: (kx * (a.0 + a.1), ky * (b.0 + b.1)), within: (min(kx, ky), max(kx, ky)))
        // An edge dropped on the opposite edge zeroes only the local axis nearest its world axis, as at 0°, so the
        // layer keeps a size a later drag can grow (#655).
        if !handle.isCorner, f.x == 0, f.y == 0 {
            f = movesOnlyX(handle) == alongX ? (0, 1) : (1, 0)
        }
        // A world axis that crossed its fixed handle mirrors the local axis nearest it; both crossing is a half turn.
        let flipX = (wx < 0 && alongX) || (wy < 0 && !alongX), flipY = (wy < 0 && alongX) || (wx < 0 && !alongX)
        let (sx, sy) = (t.scaleX * f.x * (flipX ? -1 : 1), t.scaleY * f.y * (flipY ? -1 : 1))
        guard let moved = Rect(enclosing: points.map((turn * Matrix.scale(x: sx, y: sy)).apply)) else { return nil }
        // The layer's own fixed handle goes where the box's stretch takes it: for a lone layer, it stays put. On a
        // mirrored axis the moved box meets it with its grip side.
        let from = spot(opposite(handle), on: own), stay = spot(opposite(handle), on: moved)
        let swap = spot(handle, on: moved)
        let anchor = Point(x: wx < 0 ? swap.x : stay.x, y: wy < 0 ? swap.y : stay.y)
        let target = Point(x: fixed.x + wx * (from.x - fixed.x), y: fixed.y + wy * (from.y - fixed.y))
        return ["x": target.x - anchor.x, "y": target.y - anchor.y, "scaleX": sx, "scaleY": sy]
    }
    /// The local stretch f, both parts within `range`, whose world size (a·f, b·f) lands nearest `target`; of equally
    /// near ones (at 45° there are many), the most even. A convex fit on a box: the exact answer if it lies inside,
    /// else the best point on the box's sides, or on its diagonal.
    private static func fit(_ a: (Double, Double), _ b: (Double, Double), to target: (Double, Double),
                            within range: (Double, Double)) -> (x: Double, y: Double) {
        let (lo, hi) = range, (tx, ty) = target
        func clamp(_ x: Double) -> Double { min(max(x, lo), hi) }
        func miss(_ f: (x: Double, y: Double)) -> Double {
            let dx = a.0 * f.x + a.1 * f.y - tx, dy = b.0 * f.x + b.1 * f.y - ty
            return dx * dx + dy * dy
        }
        let det = a.0 * b.1 - a.1 * b.0, (p, q) = (a.0 + a.1, b.0 + b.1), even = clamp(ratio(p * tx + q * ty, p * p + q * q))
        var tries: [(x: Double, y: Double)] = [(ratio(tx * b.1 - a.1 * ty, det), ratio(a.0 * ty - b.0 * tx, det)), (even, even)]
        for side in [lo, hi] {
            tries.append((side, clamp(ratio(a.1 * (tx - a.0 * side) + b.1 * (ty - b.0 * side), a.1 * a.1 + b.1 * b.1))))
            tries.append((clamp(ratio(a.0 * (tx - a.1 * side) + b.0 * (ty - b.1 * side), a.0 * a.0 + b.0 * b.0)), side))
        }
        let slack = 1e-12 * max(1, hi)
        let inside = tries.filter { [$0.x, $0.y].allSatisfy { $0.isFinite && $0 >= lo - slack && $0 <= hi + slack } }
        let least = inside.map(miss).min() ?? 0
        let near = inside.filter { miss($0) <= least + 1e-9 * max(1, least) }
        return near.min { abs($0.x - $0.y) < abs($1.x - $1.y) } ?? (even, even)
    }
    /// How near (in points) a Scale drop must land to the opposite line to count as on it: far above the rounding a
    /// viewport round trip adds, far below anything a pointer can aim at (#698).
    private static let lineTolerance = 1e-6
    /// `a / b`, or 1 when that is not a finite number.
    private static func ratio(_ a: Double, _ b: Double) -> Double { b != 0 && (a / b).isFinite ? a / b : 1 }
    /// Handle `h` (0...7 clockwise from top-left, taken mod 8) on `box`, where the stage draws it: the kernel's
    /// `EditorHandle` of that number.
    public static func handle(_ h: Int, on box: Rect) -> Point { spot(editorHandle(h), on: box) }
    /// The four corners of `r`, clockwise from top-left.
    static func corners(_ r: Rect) -> [Point] {
        [Point(x: r.minX, y: r.minY), Point(x: r.maxX, y: r.minY), Point(x: r.maxX, y: r.maxY), Point(x: r.minX, y: r.maxY)]
    }
}
