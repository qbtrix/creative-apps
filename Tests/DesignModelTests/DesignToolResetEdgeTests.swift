// DesignToolResetEdgeTests.swift: edge cases of a drawing tool going back to Move
// after one shape (#269): long and Shift drags, nested frames, gestures that never
// start or are cut short, a tool switch mid-gesture, and Text placements that are
// cancelled or left blank. Runs on Linux and macOS.
import DesignModel
import Testing

@Test(arguments: [DesignTool.frame, .rectangle, .ellipse])
func aLongShiftDrawStaysOnItsToolUntilThePointerLifts(_ tool: DesignTool) {
    var workspace = openDesign()
    workspace.selectTool(tool)
    for step in 0..<20 {
        let offset = Double(step) * 7
        workspace.drag(from: pt(40, 40), to: pt(60 + offset, 90 + offset / 2), modifiers: .shift)
        #expect(workspace.tool == tool)
    }
    workspace.endDrag()
    #expect(workspace.tool == .move)
    #expect(workspace.treeNode("node-2")?.kind == tool.nodeKind)
    #expect(workspace.treeNode("node-3") == nil, "one gesture adds one node")
}

@Test(arguments: [DesignTool.frame, .rectangle, .ellipse, .text])
func aToolDrawnInsideANestedFrameStillReturnsToMove(_ tool: DesignTool) throws {
    var workspace = openDesign()
    try workspace.addNode(.frame, frame: rc(100, 100, 400, 300), in: "node-1")
    workspace.gesture(tool, pt(150, 150), pt(250, 220))
    #expect(workspace.tool == .move)
    #expect(workspace.treeNode("node-2")?.children.first?.id == "node-3")
}

@Test(arguments: [DesignTool.frame, .rectangle, .ellipse, .text])
func aGestureThatNeverStartsKeepsTheTool(_ tool: DesignTool) {
    var workspace = openDesign()
    workspace.selectTool(tool)
    workspace.drag(from: pt(.nan, 40), to: pt(100, 100))
    workspace.drag(from: pt(40, 40), to: pt(.infinity, 100))
    workspace.endDrag()
    #expect(workspace.tool == tool, "nothing was added, so the tool stays")
    #expect(workspace.treeNode("node-2") == nil)
}

@Test(arguments: [DesignTool.frame, .rectangle, .ellipse])
func aBareEndDragWithoutAGestureKeepsTheTool(_ tool: DesignTool) {
    var workspace = openDesign()
    workspace.selectTool(tool)
    workspace.endDrag()
    workspace.endDrag()
    #expect(workspace.tool == tool)
}

@Test func choosingAnotherToolMidDrawKeepsTheShapeAndTheChosenTool() {
    var workspace = openDesign()
    workspace.selectTool(.rectangle)
    workspace.drag(from: pt(40, 40), to: pt(200, 160))
    workspace.selectTool(.ellipse)
    #expect(workspace.tool == .ellipse, "the tool the user picked wins over the reset")
    #expect(workspace.treeNode("node-2")?.kind == .rectangle)
    workspace.gesture(.ellipse, pt(300, 300), pt(400, 380))
    #expect(workspace.tool == .move && workspace.treeNode("node-3")?.kind == .ellipse)
}

@Test func undoWaitsWhileADrawRunsAndTheToolResetsWhenItEnds() {
    var workspace = openDesign()
    workspace.selectTool(.frame)
    workspace.drag(from: pt(40, 40), to: pt(200, 160))
    workspace.undo()
    #expect(workspace.tool == .frame && workspace.treeNode("node-2") != nil)
    workspace.endDrag()
    workspace.undo()
    #expect(workspace.tool == .move && workspace.treeNode("node-2") == nil)
}

@Test func newFileMidDrawEndsTheDrawAndLeavesMove() {
    var workspace = openDesign()
    workspace.selectTool(.ellipse)
    workspace.drag(from: pt(40, 40), to: pt(200, 160))
    workspace.newFile()
    #expect(workspace.tool == .move)
    workspace.undo()
    #expect(workspace.treeNode("node-2")?.kind == .ellipse, "the shape drawn before New File comes back")
}

@Test func aCancelledOrBlankTextPlacementLeavesMove() {
    for finish in ["cancel", "blank"] {
        var workspace = openDesign()
        workspace.gesture(.text, pt(100, 100), pt(100, 100))
        if finish == "cancel" {
            workspace.cancelTextEdit()
        } else {
            workspace.setTextDraft("   ")
            workspace.commitTextEdit()
        }
        #expect(workspace.tool == .move)
        #expect(workspace.treeNode("node-2") == nil)
        #expect(workspace.selectedNodeID == nil)
    }
}

@Test func aTextDragStillPlacesOneNodeAndReturnsToMove() {
    var workspace = openDesign()
    workspace.selectTool(.text)
    workspace.drag(from: pt(100, 100), to: pt(180, 140))
    workspace.drag(from: pt(180, 140), to: pt(260, 200))
    #expect(workspace.tool == .text)
    workspace.endDrag()
    #expect(workspace.tool == .move && workspace.editingTextID == "node-2")
    #expect(workspace.treeNode("node-3") == nil)
}

@Test func pressingMoveRightAfterAShapeSelectsTheShapeUnderThePointer() {
    var workspace = openDesign()
    workspace.gesture(.rectangle, pt(40, 40), pt(200, 160))
    workspace.deselect()
    workspace.drag(from: pt(120, 100), to: pt(150, 130))
    workspace.endDrag()
    #expect(workspace.selectedNodeID == "node-2")
    #expect(workspace.treeNode("node-2")?.frame == rc(70, 70, 160, 120), "the drag moved the shape it hit")
    #expect(workspace.treeNode("node-3") == nil)
}
