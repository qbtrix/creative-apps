// SceneRemoveReasonTests.swift: Remove Scene's disabled reason names a step that works. A machine's initial state
// can't be removed, so when it is on the scene the reason says so and points to moving it or removing the machine;
// following the reason's own advice re-enables Remove Scene (#694).
import FlareCore
@testable import FlareModel
import Testing

let initialOnSceneHelp = "The machine \u{201C}Button\u{201D} starts in \u{201C}idle\u{201D} on this scene, and its initial "
    + "state can't be removed. Move that state to another scene or remove the machine first."
private let statesOnSceneHelp = "The machine \u{201C}Button\u{201D} uses this scene. Move its states on this scene to "
    + "another scene or remove them first."

/// The issue's repro: a machine whose only state, its initial one, is on scene `a`, with a second scene `b` added.
private func machineOnFirstScene() -> (FlareWorkspace, String, String) {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.button)
    let a = w.selectedSceneID ?? ""
    w.addMachine(named: "Button", firstStateLabel: "idle")
    w.addScene()
    let b = w.selectedSceneID ?? ""
    w.selectScene(a)
    return (w, a, b)
}

@Test func theReasonForABlockingInitialStateDoesNotSayToRemoveIt694() {
    var (w, a, _) = machineOnFirstScene()
    #expect(w.sceneRemoveHelp(a) == initialOnSceneHelp)
    // The old advice is still refused, which is why the reason no longer gives it.
    w.removeMachineState("idle")
    #expect(w.machineError == "idle is the initial state." && w.sceneRemoveHelp(a) != nil)
}

@Test func movingTheInitialStateToAnotherSceneReEnablesRemoveScene694() throws {
    var (w, a, b) = machineOnFirstScene()
    var idle = try #require(w.machine?.states.first { $0.sceneID == a })
    idle.sceneID = b
    w.updateMachineState(idle)
    #expect(w.machineError == nil && w.sceneRemoveHelp(a) == nil)
    w.removeScene(a)
    #expect(w.layerError == nil && w.scenes.map(\.id) == [b])
}

@Test func removingTheMachineReEnablesRemoveScene694() throws {
    var (w, a, _) = machineOnFirstScene()
    let id = try #require(w.machine?.id)
    w.removeMachine(id)
    #expect(w.machineError == nil && w.sceneRemoveHelp(a) == nil)
}

@Test func aBlockingNonInitialStateIsRemovedOrMovedAsTheReasonSays694() throws {
    var (w, a, b) = machineOnFirstScene()
    w.addMachineState(fromLabel: "hover")
    var idle = try #require(w.machine?.states.first { $0.id == "idle" })
    idle.sceneID = b
    w.updateMachineState(idle)
    #expect(w.machineError == nil && w.machine?.states.first { $0.sceneID == a }?.id == "hover")
    #expect(w.sceneRemoveHelp(a) == statesOnSceneHelp)
    var moved = w
    for s in w.machine?.states ?? [] where s.sceneID == a { w.removeMachineState(s.id) }
    #expect(w.machineError == nil && w.sceneRemoveHelp(a) == nil)
    var hover = try #require(moved.machine?.states.first { $0.id == "hover" })
    hover.sceneID = b
    moved.updateMachineState(hover)
    #expect(moved.machineError == nil && moved.sceneRemoveHelp(a) == nil)
}
