// DesignGestureTests.swift: how drag(from:to:) treats a stream of pointer
// moves. The canvas sends (previous point, current point) each time, so only the
// first call's start counts; later calls are recomputed from it. Also what a
// gesture ignores or ends. Runs on Linux and macOS.
import DesignModel
import Testing

@Test func aStreamOfMovesEqualsOneDragFromTheFirstStart() {
    var streamed = openDesign()
    streamed.selectTool(.rectangle)
    streamed.drag(from: pt(40, 40), to: pt(60, 50))
    streamed.drag(from: pt(60, 50), to: pt(120, 90))
    streamed.drag(from: pt(120, 90), to: pt(200, 160))
    streamed.endDrag()
    var whole = openDesign()
    whole.gesture(.rectangle, pt(40, 40), pt(200, 160))
    #expect(streamed == whole)
    #expect(streamed.frame("node-2") == rc(40, 40, 160, 120))
}

@Test func aStreamedMoveDoesNotDrift() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(100, 100, 100, 100), in: "node-1")
    workspace.selectTool(.move)
    workspace.drag(from: pt(150, 150), to: pt(160, 150))
    workspace.drag(from: pt(160, 150), to: pt(170, 160))
    workspace.drag(from: pt(170, 160), to: pt(155, 152))
    workspace.endDrag()
    #expect(workspace.frame("node-2") == rc(105, 102, 100, 100))
}

@Test func nonFinitePointsAreIgnored() {
    var workspace = openDesign()
    workspace.selectTool(.rectangle)
    let before = workspace
    workspace.drag(from: pt(.nan, 0), to: pt(10, 10))
    workspace.drag(from: pt(0, 0), to: pt(.infinity, 10))
    #expect(workspace == before)
    workspace.drag(from: pt(0, 0), to: pt(10, 10))
    workspace.drag(from: pt(10, 10), to: pt(.nan, .nan))
    workspace.endDrag()
    #expect(workspace.frame("node-2") == rc(0, 0, 10, 10))
}

@Test func theDragHasNoEffectWithNoFileOpen() {
    var workspace = DesignWorkspace()
    workspace.drag(from: pt(0, 0), to: pt(10, 10))
    workspace.endDrag()
    #expect(workspace == DesignWorkspace())
}

@Test func theMoveToolOnNothingKeepsTheDocument() {
    var workspace = openDesign()
    let before = workspace.pages
    workspace.gesture(.move, pt(-50, -50), pt(-20, -20))
    #expect(workspace.pages == before && !workspace.canUndo)
}

@Test func aStrayEndDragChangesNothing() {
    var workspace = openDesign()
    let before = workspace
    workspace.endDrag()
    #expect(workspace == before)
}

@Test func switchingToolsEndsTheDragAndRecordsIt() {
    var workspace = openDesign()
    workspace.selectTool(.rectangle)
    workspace.drag(from: pt(0, 0), to: pt(30, 30))
    workspace.selectTool(.move)
    #expect(workspace.frame("node-2") == rc(0, 0, 30, 30))
    #expect(workspace.undoActionName == "Undo Add Rectangle")
    workspace.undo()
    #expect(workspace.treeNode("node-2") == nil)
}

@Test func aWiderToleranceMakesHandlesEasierToHit() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(40, 40, 160, 120), in: "node-1")
    workspace.setHandleTolerance(10)
    workspace.gesture(.move, pt(206, 166), pt(216, 176))
    #expect(workspace.frame("node-2") == rc(40, 40, 170, 130))
}
