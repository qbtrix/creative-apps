// SceneRemoveMachineTests.swift: Remove Scene follows the engine's rule that a machine state's scene must exist, so a
// scene a machine uses is disabled with a plain reason, and a refusal never shows engine debug text (#683).
import FlareCore
@testable import FlareModel
import Testing

private func buttonWithMachineOnFirstScene() -> (FlareWorkspace, String) {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.button)
    let a = w.selectedSceneID ?? ""
    w.addMachine(named: "Button", firstStateLabel: "idle")
    w.addScene()
    w.selectScene(a)
    return (w, a)
}

@Test func removeSceneIsDisabledForASceneAMachineUses683() {
    let (w, a) = buttonWithMachineOnFirstScene()
    #expect(w.machines.count == 1 && w.scenes.count == 2)
    #expect(w.sceneRemoveHelp(a) == initialOnSceneHelp)
}

@Test func removingASceneAMachineUsesIsRefusedInPlainWords683() {
    var (w, a) = buttonWithMachineOnFirstScene()
    let before = w.document
    w.removeScene(a)
    #expect(w.document == before && w.scenes.count == 2)
    #expect(w.layerError?.message == w.sceneRemoveHelp(a))
}

@Test func removeSceneStaysEnabledAndWorksForASceneNoMachineUses683() throws {
    var (w, a) = buttonWithMachineOnFirstScene()
    let b = try #require(w.scenes.last?.id)
    #expect(b != a && w.sceneRemoveHelp(b) == nil)
    w.selectScene(b)
    w.removeScene(b)
    #expect(w.layerError == nil && w.scenes.map(\.id) == [a] && w.machines.count == 1)
}

@Test func anEngineRefusalOfRemoveSceneIsPlainWords683() {
    #expect(FlareWorkspace.sceneRemoveMessage(.invalidDocument("Delete Scene: invalid(\"state machine machine-1: x\")"))
        == "The scene could not be removed.")
    #expect(FlareWorkspace.sceneRemoveMessage(.sceneNotFound("scene-9")) == "This scene is no longer in the document.")
}
