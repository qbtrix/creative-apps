// FlareDrawing.swift: the Ellipse tool on FlareWorkspace. A drag spans a box
// from its start to the pointer; `draft` is the ellipse inscribed in that box
// while the drag runs, and the drag's end commits it as a new "Ellipse N"
// layer above the selected one, in one "Add Ellipse" undo step. A drag whose
// box is narrower or shorter than `minimumEllipseExtent` stage points (a click
// with pointer jitter) adds nothing, at whatever scale the stage is fit to; a
// degenerate scale (zero, negative, NaN, or one whose minimum overflows) adds
// nothing at all.
import FlareCore

extension FlareWorkspace {
    /// The smallest width and height, in stage (view) points, a drag's box
    /// needs to make an ellipse. A click's sub-point pointer jitter stays below
    /// it, so it adds no invisible layer and no undo step.
    public static let minimumEllipseExtent = 1.0

    /// `minimumEllipseExtent` in scene points on a stage drawn at `stageScale`
    /// stage points per scene point (its fit scale). It never shrinks as the
    /// scale does: a scale so small the minimum overflows, a zero, negative,
    /// -infinity or NaN scale give +infinity, which no box can meet, so no
    /// drag commits; +infinity gives the smallest positive one, so an empty
    /// box still doesn't.
    public static func minimumEllipseExtent(atStageScale stageScale: Double) -> Double {
        guard stageScale > 0 else { return .infinity }  // also NaN
        let extent = minimumEllipseExtent / stageScale
        guard extent.isFinite else { return .infinity }
        return max(extent, .leastNonzeroMagnitude)
    }

    /// The ellipse inscribed in the box from `start` to `end`, as four cubic
    /// quarters with the box's edge midpoints as the polyline fallback; nil
    /// when the box is narrower or shorter than `minimumEllipseExtent` stage
    /// points at `stageScale` (see `minimumEllipseExtent(atStageScale:)`), or a
    /// coordinate, the centre or a radius is not finite. The centre is the
    /// box's min corner plus half its size, so corners near the largest finite
    /// value don't overflow their sum.
    /// Stopgap until FlareCore's `Shape.ellipse(in:)` (qbtrix/creative-core#182)
    /// lands; then this returns that builder's shape.
    public static func ellipse(from start: Point, to end: Point, stageScale: Double = 1) -> FlareShape? {
        let width = abs(end.x - start.x), height = abs(end.y - start.y)
        let minimum = minimumEllipseExtent(atStageScale: stageScale)
        guard width.isFinite, height.isFinite, width >= minimum, height >= minimum
        else { return nil }
        let rx = width / 2, ry = height / 2
        let c = Point(x: min(start.x, end.x) + rx, y: min(start.y, end.y) + ry)
        guard c.x.isFinite, c.y.isFinite, rx.isFinite, ry.isFinite else { return nil }
        let k = 0.5522847498  // a quarter circle's control distance, as a fraction of the radius
        // The unit circle at 0°, 90°, 180°, 270° and back to 0°.
        let units: [(cos: Double, sin: Double)] = [(1, 0), (0, 1), (-1, 0), (0, -1), (1, 0)]
        func at(_ u: (cos: Double, sin: Double), along t: Double) -> Point {
            // The point at `u` moved `t` along its tangent (-sin, cos).
            Point(x: c.x + rx * (u.cos - t * u.sin), y: c.y + ry * (u.sin + t * u.cos))
        }
        var elements: [PathElement] = [.move(to: at(units[0], along: 0))]
        for (from, to) in zip(units, units.dropFirst()) {
            elements.append(.cubic(control1: at(from, along: k), control2: at(to, along: -k), to: at(to, along: 0)))
        }
        let points = units.dropLast().map { at($0, along: 0) }
        // The edge midpoints are the box's extremes; every control point lies inside.
        guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        return FlareShape(points: points, path: FlarePath(elements: elements + [.close]))
    }

    /// Adds the ellipse from `start` to `end` as a new "Ellipse N" layer (the
    /// smallest N no layer uses as a name or id) above the selected layer, on
    /// top without one, and selects it. One "Add Ellipse" undo step.
    mutating func commitEllipse(from start: Point, to end: Point, stageScale: Double) {
        guard let shape = Self.ellipse(from: start, to: end, stageScale: stageScale) else { return }
        guard let scene = selectedScene else { return refuse(.noDocument) }
        let taken = Set(scenes.flatMap { $0.layers.flatMap { [$0.id, $0.name] } })
        var n = 1
        while taken.contains("ellipse-\(n)") || taken.contains("Ellipse \(n)") { n += 1 }
        let layer = Layer(id: "ellipse-\(n)", name: "Ellipse \(n)")
        let below = scene.layers.firstIndex { $0.id == selectedLayerID }
        applyGroup("Add Ellipse", selection: .layer(layer.id)) { engine in
            try engine.perform(AddLayer(owner: .scene(scene.id), layer: layer, index: below.map { $0 + 1 }))
            try engine.perform(AddShape(owner: .scene(scene.id), layerID: layer.id, shape: shape))
        }
    }
}
