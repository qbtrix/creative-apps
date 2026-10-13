// WorkspaceWiringTests.swift: FlareWorkspace over FlareServices (LM-0a3). A
// pointer move only changes the draft, marquee or preview; mouse-up commits one
// named undo step; clicks and marquees select; `toolHelp` asks the services.
import FlareCore
@testable import FlareModel
import Testing

private func workspace(_ document: Document, _ tool: FlareTool) -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    workspace.load(document)
    workspace.selectTool(tool)
    return workspace
}

private func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }

private func ball(_ w: FlareWorkspace) -> Layer? { w.document?.scenes.first?.layers.first { $0.id == "ball" } }

@Test func aRectangleDragDraftsThenCommitsOneAddRectangle() {
    var w = workspace(FlareFixtures.empty, .rectangle)
    w.dragChanged(from: p(40, 40), to: p(200, 160))
    w.cancelDrag()
    w.endDrag()
    w.drag(from: p(40, 40), to: p(40.3, 40.4))  // a click with jitter
    #expect(w.draft == nil && w.document == FlareFixtures.empty && !w.canUndo)
    w.dragChanged(from: p(40, 40), to: p(200, 160))
    #expect(w.document == FlareFixtures.empty && w.draft?.tool == .rectangle)
    w.endDrag()
    #expect(w.draft == nil && w.layers.map(\.name) == ["Rectangle 1"] && w.selectedLayerID == "rectangle-1")
    #expect(w.undoActionName == "Undo Add Rectangle")
    w.undo()
    #expect(w.document == FlareFixtures.empty && !w.canUndo)
}

@Test func aSelectDragOnBounceMovesBallInOneMove() {
    var w = workspace(FlareFixtures.bounce, .select)
    w.dragChanged(from: p(80, 100), to: p(130, 120))
    let moved = w.dragPreview?.items.first { $0.address.layerID == "ball" }
    #expect(w.document == FlareFixtures.bounce && moved?.transform.tx == 130 && moved?.transform.ty == 120)
    w.endDrag()
    #expect(ball(w)?.tracks["x"]?.first?.value == 130 && ball(w)?.tracks["y"]?.first?.value == 120)
    #expect(w.undoActionName == "Undo Move" && w.dragPreview == nil && w.selectedLayerIDs == ["ball"])
    w.undo()
    #expect(w.document == FlareFixtures.bounce && !w.canUndo)
}

@Test func clicksAndAMarqueeSelectLikeJ5() {
    var w = workspace(FlareFixtures.bounce, .select)
    w.drag(from: p(80, 100), to: p(80.4, 100.2))  // a click with jitter selects, never moves
    #expect(w.selectedLayerIDs == ["ball"])
    w.drag(from: p(275, 352), to: p(275, 352), modifiers: .shift)
    #expect(w.selectedLayerIDs == ["ball", "shadow"])
    w.drag(from: p(500, 30), to: p(500, 30))
    #expect(w.selection.isEmpty && w.selectedLayerID == nil)
    w.dragChanged(from: p(1, 1), to: p(549, 399))
    #expect(w.marquee == Rect(minX: 1, minY: 1, maxX: 549, maxY: 399))
    w.endDrag()
    #expect(w.marquee == nil && Set(w.selectedLayerIDs) == ["ball", "shadow"])  // Background is locked
    w.drag(from: p(275, 352), to: p(275, 352), modifiers: .shift)
    #expect(w.selectedLayerIDs == ["ball"] && w.document == FlareFixtures.bounce && !w.canUndo)
}

@Test func aDirectSelectDragMovesTheShapeNotTheLayer() {
    var w = workspace(FlareFixtures.bounce, .directSelect)
    w.drag(from: p(80, 100), to: p(90, 100))
    #expect(w.selection == [StageAddress(owner: .scene("scene-1"), layerID: "ball", item: .shape(0))])
    #expect(ball(w)?.tracks == FlareFixtures.bounce.scenes.first?.layers.last?.tracks)
    #expect(ball(w)?.shapes.first?.points.first?.x == 40)  // its right edge, 30 from the origin, moved 10
    #expect(w.undoActionName == "Undo Move")
}

@Test func aPenPathGrowsAcrossClicksAndCommitsWhenClosed() {
    var w = workspace(FlareFixtures.empty, .pen)
    for point in [p(10, 10), p(100, 10), p(100, 100)] { w.drag(from: point, to: point) }
    #expect(w.draft?.anchors.count == 3 && w.document == FlareFixtures.empty)
    w.drag(from: p(11, 11), to: p(11, 11))
    #expect(w.draft == nil && w.layers.map(\.name) == ["Path 1"] && w.undoActionName == "Undo Add Path")
}

@Test func toolHelpAsksTheServices() {
    #expect(FlareWorkspace().toolHelp(.rectangle) == "Not connected yet (IN-1)." && FlareWorkspace().toolHelp(.ellipse) == nil)
    #expect(FlareTool.allCases.allSatisfy { FlareWorkspace(services: .fake()).toolHelp($0) == nil })
    var off = FlareServices.fake()
    off.shapes = FakeShapes(unavailable: "")
    #expect(FlareWorkspace(services: off).toolHelp(.pen) == FlareTool.pen.unavailableHelp)
}

@Test func aLabelledStepIsOneNamedEntryAndLoadClearsTheRest() {
    var w = workspace(FlareFixtures.bounce, .select)
    w.step("Cut") { engine in
        for id in ["a", "b"] { try engine.perform(AddLayer(owner: .scene("scene-1"), layer: Layer(id: id, name: id))) }
    }
    #expect(w.layers.count == 5 && w.undoActionName == "Undo Cut")
    w.drag(from: p(80, 100), to: p(80, 100))
    w.dragChanged(from: p(1, 1), to: p(20, 20))
    w.currentFrame = 12
    w.load(FlareFixtures.bounce)
    #expect(w == workspace(FlareFixtures.bounce, .select))
}
