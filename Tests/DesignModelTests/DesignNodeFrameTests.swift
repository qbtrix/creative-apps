// DesignNodeFrameTests.swift: DesignWorkspace.setNodeFrame, the inspector's
// X, Y, W and H (#183, model part), and setFill. Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1) holds a group (node-2) holding a rectangle (node-3).
private func sample() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(100, 100, 300, 200), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(120, 130, 50, 40), in: "node-2")
    return workspace
}

@Test func setNodeFrameReadsBack() throws {
    var workspace = try sample()
    try workspace.setNodeFrame("node-3", x: 10, y: 20, width: 30, height: 40)
    #expect(workspace.frame("node-3") == rc(10, 20, 30, 40))
    #expect(workspace.undoActionName == "Undo Change Frame")
}

@Test func sizesClampToOne() throws {
    var workspace = try sample()
    try workspace.setNodeFrame("node-3", x: 0, y: 0, width: 0, height: -7)
    #expect(workspace.frame("node-3") == rc(0, 0, 1, 1))
}

@Test func aNonFinitePartKeepsItsOldValue() throws {
    var workspace = try sample()
    try workspace.setNodeFrame("node-3", x: .nan, y: 7, width: .infinity, height: 9)
    #expect(workspace.frame("node-3") == rc(120, 7, 50, 9))
    try workspace.setNodeFrame("node-3", x: 3, y: -.infinity, width: 4, height: .nan)
    #expect(workspace.frame("node-3") == rc(3, 7, 4, 9))
}

@Test func anUnknownOrLockedNodeThrowsAndChangesNothing() throws {
    var workspace = try sample()
    let before = workspace
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.setNodeFrame("nope", x: 1, y: 1, width: 1, height: 1) }
    try workspace.setNodeLocked("node-3", true)
    let locked = workspace
    #expect(throws: DesignTreeError.locked("node-3")) { try workspace.setNodeFrame("node-3", x: 1, y: 1, width: 1, height: 1) }
    #expect(workspace == locked)
    #expect(before.treeNode("node-3")?.isLocked == false && locked.treeNode("node-3")?.isLocked == true)
}

@Test func changingXOrYMovesTheSubtreeButResizingLeavesTheChildren() throws {
    var workspace = try sample()
    try workspace.setNodeFrame("node-2", x: 110, y: 90, width: 300, height: 200)
    #expect(workspace.frame("node-2") == rc(110, 90, 300, 200))
    #expect(workspace.frame("node-3") == rc(130, 120, 50, 40))
    try workspace.setNodeFrame("node-2", x: 110, y: 90, width: 500, height: 100)
    #expect(workspace.frame("node-2") == rc(110, 90, 500, 100))
    #expect(workspace.frame("node-3") == rc(130, 120, 50, 40))
}

@Test func theSameFrameRecordsNothing() throws {
    var workspace = try sample()
    let before = workspace
    try workspace.setNodeFrame("node-3", x: 120, y: 130, width: 50, height: 40)
    try workspace.setNodeFrame("node-3", x: .nan, y: .nan, width: .nan, height: .nan)
    #expect(workspace == before)
}

@Test func setFillChangesOnlyThatNodeAndUndoesAsOneStep() throws {
    var workspace = try sample()
    let red = DesignColor(255, 0, 0)
    try workspace.setFill("node-3", red)
    try workspace.setFill("node-3", DesignColor(250, 0, 0))
    try workspace.setFill("node-3", red)
    #expect(workspace.treeNode("node-3")?.fill == red)
    #expect(workspace.treeNode("node-2")?.fill == DesignNodeKind.group.defaultFill)
    #expect(workspace.undoActionName == "Undo Change Fill")
    workspace.undo()
    #expect(workspace.treeNode("node-3")?.fill == DesignNodeKind.rectangle.defaultFill)
    workspace.redo()
    #expect(workspace.treeNode("node-3")?.fill == red)
}

@Test func setFillRefusesLockedAndUnknownNodes() throws {
    var workspace = try sample()
    try workspace.setNodeLocked("node-3", true)
    let before = workspace
    #expect(throws: DesignTreeError.locked("node-3")) { try workspace.setFill("node-3", .black) }
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.setFill("nope", .black) }
    #expect(workspace == before)
}
