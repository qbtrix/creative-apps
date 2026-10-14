// DesignUndoRunTests.swift: an inspector edit run (one scrub drag, one
// committed field entry) is one undo step, and endEditRun closes it, so the
// next edit to the same field on the same node is its own step (#536). Runs on
// Linux and macOS.
import DesignModel
import Testing

@Test func twoFrameRunsOnOneNodeAreTwoUndoSteps() throws {
    var workspace = openDesign()
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    try workspace.setNodeFrame(id, x: 5, y: 0, width: 10, height: 10)
    workspace.endEditRun()
    try workspace.setNodeFrame(id, x: 9, y: 0, width: 10, height: 10)
    workspace.endEditRun()
    workspace.undo()
    #expect(workspace.frame(id) == rc(5, 0, 10, 10))
    workspace.undo()
    #expect(workspace.frame(id) == rc(0, 0, 10, 10))
    #expect(workspace.undoActionName == "Undo Add Rectangle")
}

@Test func twoFillRunsOnOneNodeAreTwoUndoSteps() throws {
    var workspace = openDesign()
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    let original = try #require(workspace.treeNode(id)).fill
    try workspace.setFill(id, DesignColor(10, 20, 30))
    workspace.endEditRun()
    try workspace.setFill(id, DesignColor(40, 50, 60))
    workspace.endEditRun()
    workspace.undo()
    #expect(workspace.treeNode(id)?.fill == DesignColor(10, 20, 30))
    workspace.undo()
    #expect(workspace.treeNode(id)?.fill == original)
    #expect(workspace.undoActionName == "Undo Add Rectangle")
}

@Test func oneScrubRunStillUndoesInOneStep() throws {
    var workspace = openDesign()
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    for x in stride(from: 1.0, through: 30, by: 1) { try workspace.setNodeFrame(id, x: x, y: 0, width: 10, height: 10) }
    workspace.endEditRun()
    workspace.undo()
    #expect(workspace.frame(id) == rc(0, 0, 10, 10))
    #expect(workspace.undoActionName == "Undo Add Rectangle")
}

@Test func aRunThatEndsOnItsStartValueStillClosesTheKey() throws {
    var workspace = openDesign()
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    try workspace.setNodeFrame(id, x: 5, y: 0, width: 10, height: 10)
    workspace.endEditRun()
    // A scrub that comes back to where it started records nothing new.
    try workspace.setNodeFrame(id, x: 6, y: 0, width: 10, height: 10)
    try workspace.setNodeFrame(id, x: 5, y: 0, width: 10, height: 10)
    workspace.endEditRun()
    try workspace.setNodeFrame(id, x: 8, y: 0, width: 10, height: 10)
    workspace.endEditRun()
    workspace.undo()
    #expect(workspace.frame(id) == rc(5, 0, 10, 10))
}

@Test func endingARunWithNothingToUndoChangesNothing() {
    var workspace = DesignWorkspace()
    workspace.endEditRun()
    #expect(!workspace.canUndo && workspace.undoActionName == "Undo")
}
