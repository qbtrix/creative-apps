// MachineStateFramesTests.swift: a state's frame range that can't apply names its real cause (#681). A reversed range
// inside the scene says the end comes before the start; frames outside the scene keep the scene message. The same
// reason is what a frame-range control shows while it is disabled, so the edit is never offered and then refused.
import FlareCore
@testable import FlareModel
import Testing

private func buttonMachine() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.button)  // scene-1 is 72 frames
    w.addMachine(named: "Button", firstStateLabel: "idle")
    return w
}

private func idle(_ start: Int, _ end: Int) -> MachineState {
    MachineState(id: "idle", name: "idle", sceneID: "scene-1", startFrame: start, endFrame: end)
}

@Test func anEndFrameBeforeTheStartFrameSaysSo() {
    var w = buttonMachine()
    let doc = w.document
    #expect(w.machineStateFramesProblem(idle(30, 10)) == FlareWorkspace.endBeforeStart)
    w.updateMachineState(idle(30, 10))
    #expect(w.machineError == "End frame must be at or after the start frame.")
    #expect(w.document == doc)
}

@Test func framesOutsideTheSceneKeepTheSceneMessage() {
    var w = buttonMachine()
    let doc = w.document
    for state in [idle(-1, 10), idle(80, 90), idle(80, 10), idle(10, 73)] {
        #expect(w.machineStateFramesProblem(state) == FlareWorkspace.framesOutsideScene, "\(state)")
        w.updateMachineState(state)
        #expect(w.machineError == "The state\u{2019}s frames must be inside the scene.", "\(state)")
    }
    #expect(w.document == doc)
}

@Test func aRangeInsideTheSceneHasNoProblemAndApplies() {
    var w = buttonMachine()
    #expect(w.machineStateFramesProblem(idle(10, 30)) == nil)
    #expect(w.machineStateFramesProblem(idle(5, 5)) == nil)
    w.updateMachineState(idle(10, 30))
    #expect(w.machineError == nil)
    #expect(w.machine?.states.first { $0.id == "idle" }?.endFrame == 30)
}
