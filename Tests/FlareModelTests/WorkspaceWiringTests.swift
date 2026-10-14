// WorkspaceWiringTests.swift: FlareWorkspace over FlareServices (blueprint LM-0a3): drafts while the pointer moves,
// one named undo step on mouse-up, cancel, click, Shift-click and move, and a labelled `step`. Linux and macOS.
import FlareCore
@testable import FlareModel
import Testing

private func opened(_ document: Document, _ tool: FlareTool) -> FlareWorkspace {
    var workspace = FlareWorkspace()
    workspace.load(document); workspace.selectTool(tool)
    return workspace
}

private let ball = Point(x: 80, y: 100), empty = FlareFixtures.empty, bounce = FlareFixtures.bounce

@Test func aRectangleDraftsDuringTheDragAndCommitsOneStepOnMouseUp() {
    var workspace = opened(empty, .rectangle)
    workspace.dragChanged(from: Point(x: 40, y: 40), to: Point(x: 200, y: 160))
    #expect(workspace.document == empty && workspace.shapeDraft?.tool == .rectangle)
    workspace.endDrag()
    #expect(workspace.layers.map(\.name) == ["Rectangle 1"] && workspace.undoActionName == "Undo Add Rectangle")
    workspace.undo()
    #expect(workspace.document == empty && !workspace.canUndo && workspace.shapeDraft == nil)
}

@Test func cancelLeavesNothingAndAPenDraftWaitsForItsClose() {
    var workspace = opened(empty, .rectangle)
    workspace.dragChanged(from: Point(x: 40, y: 40), to: Point(x: 200, y: 160))
    workspace.cancelDrag()
    workspace.endDrag()
    #expect(workspace.document == empty && !workspace.canUndo && workspace.shapeDraft == nil)
    workspace.selectTool(.pen)
    workspace.drag(from: Point(x: 10, y: 10), to: Point(x: 10, y: 10))
    workspace.drag(from: Point(x: 90, y: 10), to: Point(x: 90, y: 10))
    #expect(workspace.shapeDraft?.anchors.count == 2 && workspace.document == empty)
}

@Test func aSelectDragMovesBallInOneUndoMove() throws {
    var workspace = opened(bounce, .select)
    workspace.dragChanged(from: ball, to: Point(x: 120, y: 140))
    #expect(workspace.selectedLayerIDs == ["ball"] && workspace.document == bounce)
    #expect(workspace.dragPreview?.items.contains { $0.transform.apply(Point(x: 0, y: 0)) == Point(x: 120, y: 140) } == true)
    workspace.endDrag()
    let moved = try #require(workspace.layers.first { $0.id == "ball" })
    #expect(moved.tracks["x"]?.first?.value == 120 && moved.tracks["y"]?.first?.value == 140)
    #expect(workspace.undoActionName == "Undo Move" && workspace.dragPreview == nil)
    workspace.undo()
    #expect(workspace.document == bounce && !workspace.canUndo)
}

@Test func clickShiftClickAndAnEmptyClickPickLayers() {
    var workspace = opened(bounce, .select)
    workspace.drag(from: ball, to: ball)
    workspace.drag(from: Point(x: 275, y: 352), to: Point(x: 275, y: 352), modifiers: .shift)
    #expect(workspace.selectedLayerIDs == ["ball", "shadow"] && workspace.selectionBounds != nil)
    workspace.drag(from: Point(x: 500, y: 30), to: Point(x: 500, y: 30))
    #expect(workspace.selection.isEmpty && workspace.selectionBounds == nil && workspace.document == bounce)
}

@Test func aDirectSelectDragMovesBallsShapeNotItsLayer() {
    var workspace = opened(bounce, .directSelect)
    workspace.drag(from: ball, to: Point(x: 90, y: 110))
    #expect(workspace.selection == [StageAddress(owner: .scene("scene-1"), layerID: "ball", item: .shape(0))])
    let moved = workspace.layers.first { $0.id == "ball" }
    #expect(moved?.tracks["x"]?.first?.value == 80 && moved?.shapes.first?.points.first == Point(x: 40, y: 10))
    #expect(workspace.undoActionName == "Undo Move")
}

@Test func undoDropsAGoneLayerFromTheSelection() {
    var workspace = opened(empty, .rectangle)
    workspace.drag(from: Point(x: 40, y: 40), to: Point(x: 200, y: 160))
    workspace.selectTool(.select)
    workspace.drag(from: Point(x: 100, y: 100), to: Point(x: 100, y: 100))
    #expect(workspace.selectedLayerIDs == ["rectangle-1"])
    workspace.undo()
    #expect(workspace.selection.isEmpty && FlareWorkspace() == FlareWorkspace(services: .fake()))
}

@Test func aLabelledStepIsOneNamedUndoEntry() {
    var workspace = opened(empty, .select)
    workspace.step("Cut") { e in
        for id in ["a", "b"] { try e.perform(AddLayer(owner: .scene("scene-1"), layer: Layer(id: id, name: id))) }
    }
    #expect(workspace.layers.count == 2 && workspace.undoActionName == "Undo Cut")
    workspace.undo()
    #expect(workspace.document == empty && !workspace.canUndo)
}
