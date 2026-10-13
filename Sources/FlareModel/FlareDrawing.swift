// FlareDrawing.swift: the Ellipse tool on FlareWorkspace. A drag spans a box
// from its start to the pointer; `draft` is the ellipse inscribed in that box
// while the drag runs, and the drag's end commits it as a new "Ellipse N"
// layer above the selected one, in one "Add Ellipse" undo step. A drag with
// no width or no height adds nothing.
import FlareCore

extension FlareWorkspace {
    /// The ellipse inscribed in the box from `start` to `end`, as four cubic
    /// quarters with the box's edge midpoints as the polyline fallback; nil
    /// when the box has no area or a coordinate is not finite.
    /// Stopgap until FlareCore's `Shape.ellipse(in:)` (qbtrix/creative-core#182)
    /// lands; then this returns that builder's shape.
    public static func ellipse(from start: Point, to end: Point) -> FlareShape? {
        let rx = abs(end.x - start.x) / 2, ry = abs(end.y - start.y) / 2
        guard rx.isFinite, ry.isFinite, rx > 0, ry > 0 else { return nil }
        let c = Point(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
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
        return FlareShape(points: units.dropLast().map { at($0, along: 0) }, path: FlarePath(elements: elements + [.close]))
    }

    /// Adds the ellipse from `start` to `end` as a new "Ellipse N" layer (the
    /// smallest N no layer uses as a name or id) above the selected layer, on
    /// top without one, and selects it. One "Add Ellipse" undo step.
    mutating func commitEllipse(from start: Point, to end: Point) {
        guard let shape = Self.ellipse(from: start, to: end) else { return }
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
