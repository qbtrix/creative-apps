// FlareContextClickTests.swift: a right click on the stage picks what the context menu acts on. A hit the selection
// doesn't hold becomes the selection, so Delete removes the item under the pointer and not the one selected before; a
// hit the selection holds, or empty stage, keeps the selection. Bounce at frame 0: Ball at (80, 100), Shadow at
// (277, 353), nothing at (500, 40).
import FlareCore
@testable import FlareModel
import Testing

private let ball = Point(x: 80, y: 100), shadow = Point(x: 277, y: 353), empty = Point(x: 500, y: 40)

private func bounce() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    return w
}

@Test func theFixturePointsHitBallAndShadowAndNothing() {
    let w = bounce()
    #expect(w.stageHit(at: ball, stageScale: 1)?.layerID == "ball")
    #expect(w.stageHit(at: shadow, stageScale: 1)?.layerID == "shadow")
    #expect(w.stageHit(at: empty, stageScale: 1) == nil)
}

@Test func aRightClickOnBallWithNothingSelectedSelectsItSoCutCanAct() {
    var w = bounce()
    #expect(w.editHelp(.cut) == "Select a layer first.")
    w.contextClick(at: ball, stageScale: 1)
    #expect(w.selectedLayerIDs == ["ball"] && w.selectedLayerID == "ball")
    #expect(w.editHelp(.cut) == nil && !w.canUndo)
}

@Test func aRightClickOnBallWhileShadowIsSelectedMakesDeleteRemoveBall() {
    var w = bounce()
    w.contextClick(at: shadow, stageScale: 1)
    #expect(w.selectedLayerIDs == ["shadow"])
    w.contextClick(at: ball, stageScale: 1)
    #expect(w.selectedLayerIDs == ["ball"] && w.selectedLayerID == "ball")
    w.delete()
    #expect(w.layers.map(\.id) == ["shadow", "background"])
}

@Test func aRightClickInsideTheSelectionOrOnEmptyStageKeepsIt() {
    var w = bounce()
    w.selectAll()
    let all = w.selection
    w.contextClick(at: ball, stageScale: 1)
    #expect(w.selection == all)
    w.contextClick(at: empty, stageScale: 1)
    #expect(w.selection == all)
}
