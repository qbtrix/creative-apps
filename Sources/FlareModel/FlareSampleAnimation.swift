// FlareSampleAnimation.swift: New Sample Animation, the route into the easing
// editor while Flare can't make keyframes by hand (#204). It opens one scene
// with one layer, Ball (a circle of radius 20 at the origin), keyed on x at
// frames 0, 24 and 48 and on y at frames 0 and 24, all linear, and selects
// Ball. Built from FlareCore types only, opened with `load`, so there is no
// undo history.
import FlareCore

extension FlareWorkspace {
    public mutating func newSampleAnimation() {
        // A circle from four cubic quarters; k is the usual control distance.
        let r = 20.0, k = 20.0 * 0.5523
        let circle = Path(elements: [
            .move(to: Point(x: r, y: 0)),
            .cubic(control1: Point(x: r, y: k), control2: Point(x: k, y: r), to: Point(x: 0, y: r)),
            .cubic(control1: Point(x: -k, y: r), control2: Point(x: -r, y: k), to: Point(x: -r, y: 0)),
            .cubic(control1: Point(x: -r, y: -k), control2: Point(x: -k, y: -r), to: Point(x: 0, y: -r)),
            .cubic(control1: Point(x: k, y: -r), control2: Point(x: r, y: -k), to: Point(x: r, y: 0)),
            .close,
        ])
        let corners = [Point(x: r, y: 0), Point(x: 0, y: r), Point(x: -r, y: 0), Point(x: 0, y: -r)]
        let ball = Layer(
            id: "ball", name: "Ball",
            shapes: [Shape(points: corners, fill: .solid(Color(r: 0.09, g: 0.47, b: 0.95)), path: circle)],
            tracks: [
                "x": [Keyframe(frame: 0, value: 60), Keyframe(frame: 24, value: 275), Keyframe(frame: 48, value: 490)],
                "y": [Keyframe(frame: 0, value: 320), Keyframe(frame: 24, value: 120)],
            ])
        load(Document(scenes: [Scene(id: "scene-1", name: "Scene 1", durationFrames: 48, layers: [ball])]))
        selectLayer(ball.id)
    }
}
