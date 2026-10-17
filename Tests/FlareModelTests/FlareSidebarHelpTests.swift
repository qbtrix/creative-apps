// FlareSidebarHelpTests.swift: the sidebar's Remove reason for a scene row and the dimmed state of a layer row
// (layers-files LF-1). Runs on Linux and macOS.
import FlareCore
@testable import FlareModel
import Testing

/// `bounce` on fakes: one scene, Scene 1, with Background (locked), Shadow and Ball.
private func bounce() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    return w
}

@Test func theLastSceneCannotBeRemovedAndSaysWhy() {
    var w = bounce()
    #expect(w.removeSceneHelp("scene-1") == "An animation needs at least one scene.")
    w.addScene()
    let added = w.selectedSceneID ?? ""
    #expect(w.scenes.count == 2 && w.removeSceneHelp("scene-1") == nil && w.removeSceneHelp(added) == nil)
    w.removeScene(added)
    #expect(w.removeSceneHelp("scene-1") == "An animation needs at least one scene.")
}

@Test func aSceneAMachineUsesGivesTheMachineRule() {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.button)
    let first = w.selectedSceneID ?? ""
    w.addMachine(named: "Button", firstStateLabel: "idle")
    w.addScene()
    let second = w.selectedSceneID ?? ""
    #expect(w.removeSceneHelp(first) == initialOnSceneHelp)
    #expect(w.removeSceneHelp(second) == nil)
}

@Test func hiddenAndLockedLayersAreDimmedAndBallIsNot() {
    var w = bounce()
    #expect(w.layerRowIsDimmed("background"))
    #expect(!w.layerRowIsDimmed("ball") && !w.layerRowIsDimmed("shadow"))
    w.toggleLayerFlag("shadow", .visible)
    #expect(w.layerRowIsDimmed("shadow") && !w.layerRowIsDimmed("ball"))
    w.toggleLayerFlag("background", .locked)
    #expect(!w.layerRowIsDimmed("background"))
    #expect(!w.layerRowIsDimmed("no-such-layer"))
}
