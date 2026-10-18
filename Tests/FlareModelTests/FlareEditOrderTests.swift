// FlareEditOrderTests.swift: SE-4 of stage-edit (#1514). Bring Forward and Send Backward move the selected layer one
// step through moveLayer's ReorderLayer as one named undo entry; the top layer and a move under a locked layer refuse
// with a reason and change nothing; the selection survives the move. Bounce's layers, top first: Ball, Shadow,
// Background (locked).
import FlareCore
@testable import FlareModel
import Testing

/// Bounce open with Ball and Shadow selected on the stage (Select All skips the locked Background); Ball is the
/// panel's selected layer.
private func bounce() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    w.selectAll()
    return w
}

private func order(_ w: FlareWorkspace) -> [String] { w.layers.map(\.id) }

@Test func ballBackwardThenForwardOverShadowIsOneNamedEntryEachAndUndoRestoresTheOrder() {
    var w = bounce()
    let opened = w.document, selection = w.selection
    #expect(w.orderHelp(forward: false) == nil)
    w.sendBackward()
    #expect(order(w) == ["shadow", "ball", "background"] && w.undoActionName == "Undo Send Backward")
    #expect(w.layerError == nil && w.selection == selection && w.selectedLayerID == "ball")
    let backward = w.document
    #expect(w.orderHelp(forward: true) == nil)
    w.bringForward()
    #expect(order(w) == ["ball", "shadow", "background"] && w.undoActionName == "Undo Bring Forward")
    #expect(w.layerError == nil && w.selection == selection && w.selectedLayerID == "ball")
    w.undo()
    #expect(w.document == backward && w.undoActionName == "Undo Send Backward")
    w.undo()
    #expect(w.document == opened && !w.canUndo)
}

@Test func theTopLayerRefusesBringForwardAndNothingChanges() {
    var w = bounce()
    let before = w
    #expect(w.orderHelp(forward: true) == "Already at the front.")
    w.bringForward()
    #expect(w.layerError == .refused("Already at the front."))
    #expect(w.document == before.document && w.selection == before.selection && !w.canUndo)
    #expect(w.selectedLayerID == "ball" && order(w) == ["ball", "shadow", "background"])
}

@Test func sendingBackwardUnderTheLockedBackgroundRefusesAndNothingChanges() {
    var w = bounce()
    w.selectLayer("shadow")
    let before = w.document
    #expect(w.orderHelp(forward: false) == "Background is locked.")
    w.sendBackward()
    #expect(w.layerError == .refused("Background is locked."))
    #expect(w.document == before && !w.canUndo && w.selectedLayerID == "shadow")
}

@Test func shadowForwardOverBallKeepsShadowSelectedAndOneUndoPutsItBack() {
    var w = bounce()
    w.selectLayer("shadow")
    w.bringForward()
    #expect(order(w) == ["shadow", "ball", "background"] && w.selectedLayerID == "shadow")
    #expect(w.undoActionName == "Undo Bring Forward")
    w.undo()
    #expect(w.document == FlareFixtures.bounce && !w.canUndo && w.selectedLayerID == "shadow")
}

@Test func withNoLayerSelectedOrderIsRefusedWithAReason() {
    var w = FlareWorkspace(services: .fake())
    #expect(w.orderHelp(forward: true) == FlareLayerError.noDocument.message)
    w.load(FlareFixtures.bounce)
    #expect(w.orderHelp(forward: true) == "Select a layer first.")
    #expect(w.orderHelp(forward: false) == "Select a layer first.")
    w.sendBackward()
    #expect(w.layerError == .refused("Select a layer first.") && w.document == FlareFixtures.bounce)
}

@Test func theBottomLayerRefusesSendBackward() {
    var w = FlareWorkspace(services: .fake())
    w.newDocument()
    w.addLayer()
    w.addLayer()
    w.selectLayer("layer-1")
    let before = w.document
    #expect(w.orderHelp(forward: false) == "Already at the back.")
    w.sendBackward()
    #expect(w.document == before && w.layerError == .refused("Already at the back."))
}
