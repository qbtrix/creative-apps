// DesignUndoSwapEdgeTests.swift: adversarial cases for undoSwapsDocument and
// redoSwapsDocument (#271): repeated New File, long round trips, coalesced runs
// next to a New File step, the history limit, and Open clearing the history.
// New File over a file that already matches a fresh one changes nothing, so it
// records no step and no swap.
// Runs on Linux and macOS.
import DesignModel
import Testing

@Test func twoNewFilesInARowAreTwoSwapSteps() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    workspace.newFile()
    workspace.addPage()
    workspace.newFile()
    #expect(workspace.undoActionName == "Undo New File")
    #expect(workspace.undoSwapsDocument)
    workspace.undo()
    #expect(!workspace.undoSwapsDocument)
    #expect(workspace.redoSwapsDocument)
    workspace.undo()
    #expect(workspace.undoSwapsDocument)
    #expect(!workspace.redoSwapsDocument)
    workspace.undo()
    #expect(!workspace.undoSwapsDocument)
    #expect(workspace.redoSwapsDocument)
    workspace.redo()
    workspace.redo()
    workspace.redo()
    #expect(workspace.undoSwapsDocument)
    #expect(!workspace.redoSwapsDocument)
}

@Test func theSwapFlagSurvivesManyRoundTrips() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    workspace.newFile()
    for _ in 0..<50 {
        workspace.undo()
        #expect(workspace.redoSwapsDocument)
        #expect(!workspace.undoSwapsDocument)
        workspace.redo()
        #expect(workspace.undoSwapsDocument)
        #expect(!workspace.redoSwapsDocument)
    }
}

@Test func aNudgeRunAfterUndoingNewFileIsNotASwapAndDropsTheRedo() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    workspace.newFile()
    workspace.undo()
    workspace.selectItem("node-2")
    workspace.nudge(.right, shift: false)
    workspace.nudge(.right, shift: false)
    #expect(workspace.undoActionName == "Undo Nudge")
    #expect(!workspace.undoSwapsDocument)
    #expect(!workspace.canRedo)
    #expect(!workspace.redoSwapsDocument)
}

@Test func aNudgeRunAfterNewFileDoesNotTakeOverTheSwapStep() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    workspace.newFile()
    workspace.selectItem("node-1")
    workspace.nudge(.down, shift: true)
    workspace.nudge(.down, shift: true)
    #expect(!workspace.undoSwapsDocument)
    workspace.undo()
    #expect(workspace.undoActionName == "Undo New File")
    #expect(workspace.undoSwapsDocument)
    #expect(!workspace.redoSwapsDocument)
}

@Test func aNewFileStepPushedPastTheLimitTakesItsFlagWithIt() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    workspace.newFile()
    for _ in 0..<100 { workspace.addPage() }
    var swaps = 0
    while workspace.canUndo {
        if workspace.undoSwapsDocument { swaps += 1 }
        workspace.undo()
    }
    #expect(swaps == 0)
    #expect(!workspace.undoSwapsDocument)
}

@Test func openingAFileClearsBothSwapFlags() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    let data = try workspace.fileData()
    workspace.newFile()
    workspace.addPage()
    workspace.newFile()
    workspace.undo()
    #expect(workspace.redoSwapsDocument)
    workspace.undo()
    #expect(workspace.undoSwapsDocument)
    try workspace.open(data)
    #expect(!workspace.canUndo && !workspace.canRedo)
    #expect(!workspace.undoSwapsDocument)
    #expect(!workspace.redoSwapsDocument)
}

@Test func newFileWhileEditingTextIsStillOneSwapStepOnTop() throws {
    var workspace = openDesign()
    workspace.gesture(.text, pt(40, 40), pt(40, 40))
    let id = try #require(workspace.editingTextID)
    workspace.setTextDraft("Hello")
    workspace.newFile()
    #expect(workspace.editingTextID == nil)
    #expect(workspace.undoSwapsDocument)
    workspace.undo()
    #expect(workspace.treeNode(id)?.text == "Hello")
    #expect(!workspace.undoSwapsDocument)
    #expect(workspace.redoSwapsDocument)
}

@Test func newFileOverAnUneditedNewFileRecordsNoSwap() {
    var workspace = openDesign()
    workspace.newFile()
    #expect(!workspace.canUndo)
    #expect(!workspace.undoSwapsDocument)
}

@Test func newFileOnAnEmptyWorkspaceRecordsNoSwap() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    #expect(!workspace.canUndo)
    #expect(!workspace.undoSwapsDocument)
    #expect(!workspace.redoSwapsDocument)
}
