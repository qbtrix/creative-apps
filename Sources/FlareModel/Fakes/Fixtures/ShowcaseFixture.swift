// ShowcaseFixture.swift: `showcase`, the fixture the export and open journeys use (J22, J27). It is `bounce` plus
// one of each thing v1 can't export: a Spinner layer holding an instance of "Spin" (a square that turns a full circle
// over 24 frames), a text layer "Title" on top, and one machine, "Loop", whose single state plays the whole scene.
import FlareCore

extension FlareFixtures {
    public static let showcase: Document = {
        var document = bounce
        let square = FlareShape(points: [Point(x: -20, y: -20), Point(x: 20, y: -20), Point(x: 20, y: 20), Point(x: -20, y: 20)],
                                fill: .solid(FlareColor(r: 0.36, g: 0.3, b: 0.85)))
        let turn = Layer(id: "square", name: "Square", shapes: [square], tracks: [
            "rotation": [Keyframe(frame: 0, value: 0), Keyframe(frame: 23, value: 360)],
        ])
        document.symbols = [Symbol(id: "spin", name: "Spin", durationFrames: 24, layers: [turn])]
        document.scenes[0].layers += [
            Layer(id: "spinner", name: "Spinner", instances: [Instance(symbolID: "spin", transform: Transform(x: 470, y: 80))]),
            Layer(id: "title", name: "Title", texts: [
                TextShape(string: "Bounce", fontFamily: "System", fontSize: 36, position: Point(x: 40, y: 60)),
            ]),
        ]
        document.stateMachines = [StateMachine(
            id: "machine-1", name: "Loop",
            states: [MachineState(id: "play", name: "play", sceneID: "scene-1", startFrame: 0, endFrame: 47)],
            initialState: "play")]
        return document
    }()
}
