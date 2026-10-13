// CharacterFixture.swift: `character`, the fixture the library journeys open (J17, J18). One 550 × 400 scene, 48
// frames at 24 fps, each part on its own layer, bottom first: Legs (two rectangles), Body, Arms (one instance of the
// animated symbol "Wave": a hand that swings its rotation over 24 frames, placed at the shoulder) and Head.
import FlareCore

extension FlareFixtures {
    public static let character: Document = {
        func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: FlareColor) -> FlareShape {
            FlareShape(points: [Point(x: x, y: y), Point(x: x + w, y: y), Point(x: x + w, y: y + h), Point(x: x, y: y + h)],
                       fill: .solid(color))
        }
        let skin = FlareColor(r: 0.96, g: 0.78, b: 0.62), cloth = FlareColor(r: 0.24, g: 0.42, b: 0.85)
        let legs = Layer(id: "legs", name: "Legs", shapes: [
            box(250, 270, 18, 90, FlareColor(r: 0.2, g: 0.2, b: 0.25)),
            box(282, 270, 18, 90, FlareColor(r: 0.2, g: 0.2, b: 0.25)),
        ])
        let body = Layer(id: "body", name: "Body", shapes: [box(240, 170, 70, 105, cloth)])
        let arms = Layer(id: "arms", name: "Arms", instances: [Instance(symbolID: "wave", transform: Transform(x: 305, y: 180))])
        let head = Layer(id: "head", name: "Head", shapes: [box(250, 110, 50, 55, skin)])
        // The hand hangs from its origin, so the rotation swings it about the shoulder.
        let hand = Layer(id: "hand", name: "Hand", shapes: [box(0, 0, 14, 70, skin)], tracks: [
            "rotation": [Keyframe(frame: 0, value: -20), Keyframe(frame: 12, value: 25), Keyframe(frame: 23, value: -20)],
        ])
        return Document(
            scenes: [FlareScene(id: "scene-1", name: "Scene 1", fps: 24, durationFrames: 48, layers: [legs, body, arms, head])],
            symbols: [Symbol(id: "wave", name: "Wave", durationFrames: 24, layers: [hand])])
    }()
}
