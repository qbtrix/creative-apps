// ButtonFixture.swift: `button`, the fixture the Interactions journeys open (J19–J21). One 550 × 400 scene, 72 frames
// at 24 fps, labelled idle (0), hover (24) and pressed (48), and one Button layer whose scale rests at 1 while idle,
// grows to 1.08 for hover and dips to 0.92 when pressed. It has no machine: J19 builds it. `buttonWithMachine` adds
// that result as J20 wires it: "Hover button" with the three states, a bool input hover (default false), and the
// transitions idle → hover on "pointer" when hover == true, hover → idle when hover == false, hover → pressed on "click".
import FlareCore

extension FlareFixtures {
    public static let button: Document = {
        let keys: [(Int, Double)] = [(0, 1), (23, 1), (24, 1.08), (47, 1.08), (48, 0.92), (71, 0.92)]
        let scale = keys.map { Keyframe(frame: $0.0, value: $0.1) }
        let shape = FlareShape(points: [Point(x: -90, y: -30), Point(x: 90, y: -30), Point(x: 90, y: 30), Point(x: -90, y: 30)],
                               fill: .solid(FlareColor(r: 0.08, g: 0.42, b: 0.86)))
        let layer = Layer(id: "button", name: "Button", shapes: [shape], tracks: [
            "x": [Keyframe(frame: 0, value: 275)], "y": [Keyframe(frame: 0, value: 200)], "scaleX": scale, "scaleY": scale,
        ])
        return Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", fps: 24, durationFrames: 72, layers: [layer],
                                            labels: ["idle": 0, "hover": 24, "pressed": 48])])
    }()

    public static let buttonWithMachine: Document = {
        func state(_ id: String, _ start: Int) -> MachineState {
            MachineState(id: id, name: id, sceneID: "scene-1", startFrame: start, endFrame: start + 23)
        }
        func hover(_ on: Bool) -> [Condition] { [Condition(input: "hover", op: .equal, value: .bool(on))] }
        var document = button
        document.stateMachines = [StateMachine(
            id: "machine-1", name: "Hover button", states: [state("idle", 0), state("hover", 24), state("pressed", 48)],
            transitions: [
                FlareTransition(from: "idle", to: "hover", trigger: "pointer", conditions: hover(true)),
                FlareTransition(from: "hover", to: "idle", trigger: "pointer", conditions: hover(false)),
                FlareTransition(from: "hover", to: "pressed", trigger: "click"),
            ],
            initialState: "idle", inputs: [MachineInput(name: "hover", defaultValue: .bool(false))])]
        return document
    }()
}
