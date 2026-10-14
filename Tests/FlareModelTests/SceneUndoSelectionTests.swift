// SceneUndoSelectionTests.swift: undoing Add Scene or redoing Delete Scene moves the selection to a scene that still
// exists, the removed one's neighbour clamped to the scene list (#570).
import FlareCore
@testable import FlareModel
import Testing

private func bounce() -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    workspace.load(FlareFixtures.bounce)
    return workspace
}

@Test func undoingAddSceneSelectsTheSceneBeforeIt570() {
    var w = bounce()
    w.addScene()
    #expect(w.selectedSceneID == "scene-2")
    w.undo()
    #expect(w.scenes.map(\.id) == ["scene-1"] && w.selectedSceneID == "scene-1" && w.selectedScene != nil)
    w.redo()
    #expect(w.scenes.count == 2 && w.selectedScene != nil)
}

@Test func redoingDeleteSceneSelectsTheSceneThatTookItsPlace570() {
    var w = bounce()
    w.addScene(); w.addScene()
    w.selectScene("scene-2")
    w.removeScene("scene-2")
    #expect(w.selectedSceneID == "scene-3")
    w.undo()
    w.selectScene("scene-2")
    w.redo()
    #expect(w.scenes.map(\.id) == ["scene-1", "scene-3"] && w.selectedSceneID == "scene-3")
}

@Test func anUnselectedSceneComingAndGoingKeepsTheSelection570() {
    var w = bounce()
    w.addScene()
    w.selectScene("scene-1")
    w.undo()
    #expect(w.selectedSceneID == "scene-1")
}
