// DesignDrawTests.swift: the Frame, Rectangle and Ellipse tools (#198): a
// drag draws in any direction, a click drops a default-size shape, Shift makes
// it square, and the new node lands in the deepest visible, unlocked frame under
// the pointer. Runs on Linux and macOS.
import DesignModel
import Testing

@Test func aRectangleDragDrawsInsideTheDesktopFrameAndSelectsIt() throws {
    var workspace = openDesign()
    workspace.gesture(.rectangle, pt(40, 40), pt(200, 160))
    let node = try #require(workspace.selectedNode)
    #expect(node.id == "node-2" && node.kind == .rectangle)
    #expect(node.frame == rc(40, 40, 160, 120))
    #expect(workspace.selectedPage?.nodes.first?.children.map(\.id) == ["node-2"])
    #expect(workspace.undoActionName == "Undo Add Rectangle")
}

@Test func theReversedDragDrawsTheSameRectangle() {
    var workspace = openDesign()
    workspace.gesture(.rectangle, pt(200, 160), pt(40, 40))
    #expect(workspace.frame("node-2") == rc(40, 40, 160, 120))
    var other = openDesign()
    other.gesture(.rectangle, pt(200, 40), pt(40, 160))
    #expect(other.frame("node-2") == rc(40, 40, 160, 120))
}

@Test func theEllipseAndFrameToolsDrawTheirOwnKinds() {
    var workspace = openDesign()
    workspace.gesture(.ellipse, pt(10, 20), pt(110, 70))
    workspace.gesture(.frame, pt(300, 300), pt(500, 450))
    #expect(workspace.treeNode("node-2")?.kind == .ellipse)
    #expect(workspace.frame("node-2") == rc(10, 20, 100, 50))
    #expect(workspace.treeNode("node-3")?.kind == .frame)
    #expect(workspace.frame("node-3") == rc(300, 300, 200, 150))
    #expect(workspace.treeNode("node-3")?.fill == DesignColor.white)
    #expect(workspace.treeNode("node-2")?.fill == DesignColor.shape)
}

@Test func aClickDropsADefaultSizeShapeAtThePoint() {
    for (tool, size) in [(DesignTool.rectangle, 100.0), (.ellipse, 100), (.frame, 100)] {
        var workspace = openDesign()
        workspace.gesture(tool, pt(300, 300), pt(300, 300))
        #expect(workspace.frame("node-2") == rc(300, 300, size, size))
        #expect(workspace.undoActionName == "Undo Add \(tool.nodeKind?.defaultName ?? "")")
    }
}

@Test func shiftDrawsASquareGrowingAwayFromTheStart() {
    var workspace = openDesign()
    workspace.gesture(.rectangle, pt(40, 40), pt(200, 160), .shift)
    #expect(workspace.frame("node-2") == rc(40, 40, 160, 160))
    workspace.gesture(.ellipse, pt(200, 160), pt(40, 40), .shift)
    #expect(workspace.frame("node-3") == rc(40, 0, 160, 160))
}

@Test func aTinyDragKeepsBothSidesAtLeastOne() {
    var workspace = openDesign()
    workspace.gesture(.rectangle, pt(100, 100), pt(100.2, 100.3))
    #expect(workspace.frame("node-2") == rc(100, 100, 1, 1))
}

@Test func theNewNodeGoesIntoTheDeepestVisibleUnlockedFrameUnderTheStart() {
    var workspace = openDesign()
    workspace.gesture(.frame, pt(100, 100), pt(600, 600))
    workspace.gesture(.frame, pt(200, 200), pt(400, 400))
    workspace.gesture(.rectangle, pt(250, 250), pt(300, 300))
    #expect(workspace.treeNode("node-1")?.children.map(\.id) == ["node-2"])
    #expect(workspace.treeNode("node-2")?.children.map(\.id) == ["node-3"])
    #expect(workspace.treeNode("node-3")?.children.map(\.id) == ["node-4"])
    // A start outside the nested frames lands in the Desktop frame.
    workspace.gesture(.rectangle, pt(800, 800), pt(900, 900))
    #expect(workspace.treeNode("node-1")?.children.map(\.id) == ["node-2", "node-5"])
}

@Test func hiddenAndLockedFramesAreNotContainers() throws {
    var workspace = openDesign()
    workspace.gesture(.frame, pt(100, 100), pt(600, 600))
    try workspace.setNodeLocked("node-2", true)
    workspace.gesture(.rectangle, pt(200, 200), pt(300, 300))
    #expect(workspace.pages[0].nodes[0].children.map(\.id) == ["node-2", "node-3"])
    try workspace.setNodeLocked("node-2", false)
    try workspace.setNodeHidden("node-2", true)
    workspace.gesture(.rectangle, pt(200, 200), pt(300, 300))
    #expect(workspace.pages[0].nodes[0].children.map(\.id) == ["node-2", "node-3", "node-4"])
}

@Test func withNoFrameUnderThePointerTheNodeGoesAtThePageTop() {
    var workspace = openDesign()
    workspace.gesture(.rectangle, pt(-300, -300), pt(-200, -250))
    #expect(workspace.pages[0].nodes.map(\.id) == ["node-1", "node-2"])
    #expect(workspace.frame("node-2") == rc(-300, -300, 100, 50))
}

@Test func aDragIsOneUndoStepAndRedoKeepsTheId() {
    var workspace = openDesign()
    workspace.selectTool(.rectangle)
    for x in stride(from: 50.0, through: 200, by: 10) { workspace.drag(from: pt(40, 40), to: pt(x, 160)) }
    #expect(workspace.treeNode("node-2") != nil && workspace.canUndo == false)
    workspace.endDrag()
    #expect(workspace.frame("node-2") == rc(40, 40, 160, 120))
    workspace.undo()
    #expect(workspace.treeNode("node-2") == nil && !workspace.canUndo)
    workspace.redo()
    #expect(workspace.frame("node-2") == rc(40, 40, 160, 120))
    #expect(workspace.selectedNodeID == "node-2")
}

@Test func theDrawingToolsAreAllEnabled() {
    #expect(DesignTool.allCases.contains(.ellipse))
    for tool in [DesignTool.frame, .rectangle, .ellipse] {
        #expect(tool.isEnabled && tool.unavailableHelp == nil)
    }
    #expect(DesignTool.allCases == [.move, .frame, .rectangle, .ellipse, .text, .pen])
}

@Test func drawingNeedsAnOpenFile() {
    var workspace = DesignWorkspace()
    workspace.gesture(.rectangle, pt(0, 0), pt(10, 10))
    #expect(!workspace.isOpen && workspace.pages.isEmpty && !workspace.canUndo)
}
