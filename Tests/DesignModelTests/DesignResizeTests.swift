// DesignResizeTests.swift: resizing a node on the workspace (#200): the
// resizeNode command, the Move tool's handle drag with Shift and Option, and the
// locked and unknown refusals. DesignRectTests covers the rectangle math.
// Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1) holding a rectangle (node-2) at 40 40 160 120, selected.
private func withRectangle() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(40, 40, 160, 120), in: "node-1")
    return workspace
}

@Test func resizeNodeAppliesTheWorkedExamples() throws {
    var workspace = try withRectangle()
    try workspace.resizeNode("node-2", handle: .bottomRight, by: pt(20, 10), shift: false, option: false)
    #expect(workspace.frame("node-2") == rc(40, 40, 180, 130))
    try workspace.resizeNode("node-2", handle: .topLeft, by: pt(20, 10), shift: false, option: false)
    #expect(workspace.frame("node-2") == rc(60, 50, 160, 120))
    #expect(workspace.undoActionName == "Undo Resize")
}

@Test func shiftOnACornerKeepsFourToThree() throws {
    var workspace = try withRectangle()
    try workspace.resizeNode("node-2", handle: .bottomRight, by: pt(20, 10), shift: true, option: false)
    #expect(workspace.frame("node-2") == rc(40, 40, 180, 135))
    let frame = try #require(workspace.frame("node-2"))
    #expect(frame.width * 3 == frame.height * 4)
}

@Test func aLockedNodeKeepsItsFrame() throws {
    var workspace = try withRectangle()
    try workspace.setNodeLocked("node-2", true)
    let before = workspace
    #expect(throws: DesignTreeError.locked("node-2")) {
        try workspace.resizeNode("node-2", handle: .right, by: pt(50, 0), shift: false, option: false)
    }
    #expect(throws: DesignTreeError.unknownID("nope")) {
        try workspace.resizeNode("nope", handle: .right, by: pt(50, 0), shift: false, option: false)
    }
    #expect(workspace == before)
}

@Test func resizingAContainerLeavesItsChildren() throws {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(100, 100, 200, 200), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(120, 120, 50, 50), in: "node-2")
    try workspace.resizeNode("node-2", handle: .topLeft, by: pt(-30, -30), shift: false, option: false)
    #expect(workspace.frame("node-2") == rc(70, 70, 230, 230))
    #expect(workspace.frame("node-3") == rc(120, 120, 50, 50))
}

@Test func aMoveDragStartingOnAHandleResizes() throws {
    var workspace = try withRectangle()
    workspace.gesture(.move, pt(200, 160), pt(220, 170))
    #expect(workspace.frame("node-2") == rc(40, 40, 180, 130))
    #expect(workspace.selectedNodeID == "node-2")
    #expect(workspace.undoActionName == "Undo Resize")
}

@Test func theHandleDragHonoursShiftAndOption() throws {
    var shifted = try withRectangle()
    shifted.gesture(.move, pt(200, 160), pt(220, 170), .shift)
    #expect(shifted.frame("node-2") == rc(40, 40, 180, 135))
    var centred = try withRectangle()
    centred.gesture(.move, pt(200, 160), pt(220, 170), .option)
    #expect(centred.frame("node-2") == rc(20, 30, 200, 140))
    var both = try withRectangle()
    both.gesture(.move, pt(200, 160), pt(220, 170), [.shift, .option])
    #expect(both.frame("node-2") == rc(20, 25, 200, 150))
}

@Test func aHandleDragPastTheOppositeEdgeStopsAtOne() throws {
    var workspace = try withRectangle()
    workspace.gesture(.move, pt(200, 160), pt(-400, -400))
    #expect(workspace.frame("node-2") == rc(40, 40, 1, 1))
}

@Test func handleHitsUseTheToleranceAndTheNearestHandle() throws {
    var workspace = try withRectangle()
    #expect(workspace.handleTolerance == 6)
    #expect(workspace.handle(at: pt(200, 160)) == .bottomRight)
    #expect(workspace.handle(at: pt(204, 163)) == .bottomRight)
    #expect(workspace.handle(at: pt(120, 36)) == .top)
    #expect(workspace.handle(at: pt(120, 100)) == nil)
    workspace.setHandleTolerance(.nan)
    workspace.setHandleTolerance(0)
    workspace.setHandleTolerance(-3)
    #expect(workspace.handleTolerance == 6)
    workspace.setHandleTolerance(2)
    #expect(workspace.handle(at: pt(204, 163)) == nil)
    #expect(workspace.handle(at: pt(201, 159)) == .bottomRight)
}

@Test func lockedOrUnselectedNodesHaveNoHandles() throws {
    var workspace = try withRectangle()
    try workspace.setNodeLocked("node-2", true)
    #expect(workspace.handle(at: pt(200, 160)) == nil)
    workspace.deselect()
    try workspace.setNodeLocked("node-2", false)
    #expect(workspace.handle(at: pt(200, 160)) == nil)
}

@Test func aPressNearAHandleOfAnUnselectedNodeSelectsInsteadOfResizing() throws {
    var workspace = try withRectangle()
    workspace.deselect()
    workspace.gesture(.move, pt(200, 160), pt(220, 170))
    // No handle without a selection: the press picks the rectangle and moves it.
    #expect(workspace.frame("node-2") == rc(60, 50, 160, 120))
}
