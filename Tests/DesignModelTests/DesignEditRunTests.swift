// DesignEditRunTests.swift: an inspector edit run ends with endEditRun, so two
// separate frame or fill edits to one layer are two undo steps while one scrub
// run stays one (#536). Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1) holds a rectangle (node-2).
private func sample() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(120, 130, 50, 40), in: "node-1")
    return workspace
}

@Test func twoFrameEditsSplitByAnEndedRunAreTwoSteps() throws {
    var workspace = try sample()
    try workspace.setNodeFrame("node-2", x: 10, y: 130, width: 50, height: 40)
    workspace.endEditRun()
    try workspace.setNodeFrame("node-2", x: 20, y: 130, width: 50, height: 40)
    workspace.undo()
    #expect(workspace.frame("node-2") == rc(10, 130, 50, 40))
    workspace.undo()
    #expect(workspace.frame("node-2") == rc(120, 130, 50, 40))
}

@Test func twoFillEditsSplitByAnEndedRunAreTwoSteps() throws {
    var workspace = try sample()
    let red = DesignColor(255, 0, 0), blue = DesignColor(0, 0, 255)
    try workspace.setFill("node-2", red)
    workspace.endEditRun()
    try workspace.setFill("node-2", blue)
    workspace.undo()
    #expect(workspace.treeNode("node-2")?.fill == red)
    workspace.undo()
    #expect(workspace.treeNode("node-2")?.fill == DesignNodeKind.rectangle.defaultFill)
}

@Test func oneScrubRunStillUndoesInOneStep() throws {
    var workspace = try sample()
    for x in stride(from: 121.0, through: 140, by: 1) {
        try workspace.setNodeFrame("node-2", x: x, y: 130, width: 50, height: 40)
    }
    workspace.endEditRun()
    #expect(workspace.frame("node-2") == rc(140, 130, 50, 40))
    workspace.undo()
    #expect(workspace.frame("node-2") == rc(120, 130, 50, 40))
    #expect(workspace.undoActionName == "Undo Add Rectangle")
}

@Test func endingARunWithNothingToUndoOrTwiceChangesNothing() throws {
    var workspace = openDesign()
    let before = workspace
    workspace.endEditRun()
    workspace.endEditRun()
    #expect(workspace == before)
}
