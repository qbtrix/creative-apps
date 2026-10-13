// BounceFixture.swift: `bounce`, the fixture most journeys open. One 550 × 400 scene, 48 frames at 24 fps,
// layers bottom first: Background (the whole canvas), Shadow (a flat ellipse on the floor, not animated)
// and Ball (a circle of radius 30 about its origin) keyed on x, y, scaleX and scaleY at 0, 12, 24, 36
// and 47: it lands at 12 and 36, squashed, and is back up at 24 and 47.
import FlareCore

extension FlareFixtures {
    public static let bounce: Document = {
        let frames = [0, 12, 24, 36, 47]
        func track(_ values: [Double]) -> [Keyframe] {
            zip(frames, values).map { Keyframe(frame: $0, value: $1) }
        }
        let background = Layer(id: "background", name: "Background", shapes: [
            FlareShape(points: [Point(x: 0, y: 0), Point(x: 550, y: 0), Point(x: 550, y: 400), Point(x: 0, y: 400)],
                       fill: .solid(FlareColor(r: 0.94, g: 0.95, b: 0.97))),
        ])
        let shadow = Layer(id: "shadow", name: "Shadow", shapes: [
            ellipse(center: Point(x: 275, y: 352), rx: 40, ry: 8, color: FlareColor(r: 0, g: 0, b: 0, a: 0.25)),
        ])
        let ball = Layer(
            id: "ball", name: "Ball",
            shapes: [ellipse(center: Point(x: 0, y: 0), rx: 30, ry: 30, color: FlareColor(r: 0.95, g: 0.36, b: 0.2))],
            tracks: [
                "x": track([80, 180, 275, 370, 470]),
                "y": track([100, 320, 140, 320, 100]),
                "scaleX": track([1, 1.25, 1, 1.25, 1]),
                "scaleY": track([1, 0.75, 1, 0.75, 1]),
            ])
        return Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", fps: 24, durationFrames: 48,
                                            layers: [background, shadow, ball])])
    }()

    /// An ellipse as four cubic quarters, with its extreme points as the polyline fallback.
    private static func ellipse(center c: Point, rx: Double, ry: Double, color: FlareColor) -> FlareShape {
        let k = 0.5523  // the usual quarter-circle control distance, as a fraction of the radius
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
        return FlareShape(points: units.dropLast().map { at($0, along: 0) }, fill: .solid(color),
                          path: FlarePath(elements: elements + [.close]))
    }
}
