// CharacterFixture.swift: `character`, the fixture the symbol journeys open (J17, J18). One 550 × 400 scene, 48
// frames at 24 fps, each part on its own layer so it can animate apart, bottom first: Legs (two plain rectangles),
// Body, Arms (an instance of "Wave", a 12-frame symbol whose one layer swings an arm on rotation keys at 0, 6 and
// 12) and Head (an octagon). Nothing is keyed in the scene, so the stage looks the same at every frame but for the arm.
import FlareCore

extension FlareFixtures {
    public static let character: Document = {
        func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: FlareColor) -> FlareShape {
            FlareShape(points: [Point(x: x, y: y), Point(x: x + w, y: y), Point(x: x + w, y: y + h), Point(x: x, y: y + h)],
                       fill: .solid(color))
        }
        let (skin, shirt) = (FlareColor(r: 0.98, g: 0.8, b: 0.65), FlareColor(r: 0.2, g: 0.5, b: 0.85))
        let trousers = FlareColor(r: 0.25, g: 0.25, b: 0.3)
        let legs = Layer(id: "legs", name: "Legs", shapes: [box(245, 260, 24, 100, trousers), box(281, 260, 24, 100, trousers)])
        let body = Layer(id: "body", name: "Body", shapes: [box(235, 160, 80, 110, shirt)])
        // A regular octagon of radius 36 about (275, 120); 25.46 is 36 × cos 45°.
        let d = 25.46
        let octagon = [(36, 0), (d, d), (0, 36), (-d, d), (-36, 0), (-d, -d), (0, -36), (d, -d)]
        let head = Layer(id: "head", name: "Head", shapes: [
            FlareShape(points: octagon.map { Point(x: 275 + $0.0, y: 120 + $0.1) }, fill: .solid(skin)),
        ])
        // The arm hangs from its origin, the shoulder, and swings ±20° about it.
        let arm = Layer(id: "wave-arm", name: "Arm", shapes: [box(-8, 0, 16, 80, skin)], tracks: [
            "rotation": [Keyframe(frame: 0, value: -20), Keyframe(frame: 6, value: 20), Keyframe(frame: 12, value: -20)],
        ])
        let wave = Symbol(id: "wave", name: "Wave", durationFrames: 12, layers: [arm])
        let arms = Layer(id: "arms", name: "Arms", instances: [Instance(symbolID: "wave", transform: Transform(x: 323, y: 170))])
        return Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", fps: 24, durationFrames: 48,
                                            layers: [legs, body, arms, head])],
                        symbols: [wave])
    }()
}
