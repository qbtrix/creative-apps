// DesignToolResetTests.swift: a drawing tool is good for one shape (#269). Once
// a Frame, Rectangle or Ellipse gesture adds its node, or a Text click places its
// node, the tool goes back to Move, so the next press selects instead of drawing
// again. Runs on Linux and macOS.
import DesignModel
import Testing

@Test(arguments: [DesignTool.frame, .rectangle, .ellipse])
func aDrawingToolReturnsToMoveAfterOneShape(_ tool: DesignTool) {
    for end in [pt(200, 160), pt(40, 40)] {
        var workspace = openDesign()
        workspace.selectTool(tool)
        workspace.drag(from: pt(40, 40), to: end)
        #expect(workspace.tool == tool, "the tool stays while the gesture runs")
        workspace.endDrag()
        #expect(workspace.tool == .move)
        #expect(workspace.selectedNodeID == "node-2")
    }
}

@Test func theNextPressAfterADrawSelectsInsteadOfDrawing() {
    var workspace = openDesign()
    workspace.gesture(.rectangle, pt(40, 40), pt(200, 160))
    workspace.deselect()
    workspace.drag(from: pt(100, 100), to: pt(100, 100))
    workspace.endDrag()
    #expect(workspace.treeNode("node-3") == nil)
    #expect(workspace.selectedNodeID == "node-2")
}

@Test func theTextToolReturnsToMoveOnceItsNodeIsPlaced() {
    var workspace = openDesign()
    workspace.gesture(.text, pt(100, 100), pt(100, 100))
    #expect(workspace.tool == .move)
    #expect(workspace.editingTextID == "node-2")
    workspace.setTextDraft("Hello")
    workspace.commitTextEdit()
    #expect(workspace.tool == .move && workspace.treeNode("node-2")?.text == "Hello")
}

@Test func undoAndRedoKeepTheToolOnMove() {
    var workspace = openDesign()
    workspace.gesture(.ellipse, pt(10, 20), pt(110, 70))
    workspace.undo()
    #expect(workspace.tool == .move && workspace.treeNode("node-2") == nil)
    workspace.redo()
    #expect(workspace.tool == .move && workspace.treeNode("node-2") != nil)
}

@Test func penAndMoveGesturesLeaveTheToolAlone() {
    for tool in [DesignTool.pen, .move] {
        var workspace = openDesign()
        workspace.gesture(tool, pt(40, 40), pt(200, 160))
        #expect(workspace.tool == tool)
    }
}
