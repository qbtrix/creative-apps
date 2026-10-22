// CircleSampleFixture.swift: `gradient-circle`, the sample the gradient journey (FJ-G1) opens. One 200 × 100 scene,
// 24 frames at 24 fps, layers bottom first: Circle, RJ-F31's gradient-circle.flare (radius 40 about (50, 50), a linear
// fill left to right from blue through green to black), and Rectangle, a solid shape to its right that step 5 turns
// radial.
import FlareCore

extension FlareFixtures {
    public static let gradientCircle: Document = {
        let ring = [(90, 50), (78.25, 78.25), (50, 90), (21.75, 78.25), (10, 50), (21.75, 21.75), (50, 10), (78.25, 21.75)]
        let stops = [GradientStop(offset: 0, color: FlareColor(r: 0, g: 0, b: 1)), GradientStop(offset: 0.5, color: FlareColor(r: 0, g: 1, b: 0)),
                     GradientStop(offset: 1, color: FlareColor(r: 0, g: 0, b: 0))]
        let circle = Layer(id: "layer-1", name: "Circle", shapes: [
            FlareShape(points: ring.map { Point(x: $0.0, y: $0.1) },
                       fill: .linear(stops: stops, start: Point(x: 10, y: 50), end: Point(x: 90, y: 50))),
        ])
        let rectangle = Layer(id: "layer-2", name: "Rectangle", shapes: [
            FlareShape(points: [Point(x: 120, y: 30), Point(x: 180, y: 30), Point(x: 180, y: 70), Point(x: 120, y: 70)],
                       fill: .solid(FlareColor(r: 0.95, g: 0.36, b: 0.2))),
        ])
        return Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", fps: 24, durationFrames: 24, width: 200, height: 100,
                                            layers: [circle, rectangle])])
    }()
}
