// DesignUndoSwapTests.swift: undoSwapsDocument and redoSwapsDocument, which the
// window reads to forget its file's location when Undo or Redo of New File
// replaces the whole document (#271). Runs on Linux and macOS.
import DesignModel
import Testing

@Test func newFileUndoAndRedoStepsSwapTheDocument() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    workspace.newFile()
    #expect(workspace.undoSwapsDocument)
    #expect(!workspace.redoSwapsDocument)
    workspace.undo()
    #expect(workspace.redoSwapsDocument)
    #expect(!workspace.undoSwapsDocument)
    workspace.redo()
    #expect(workspace.undoSwapsDocument)
    #expect(!workspace.redoSwapsDocument)
}

@Test func anOrdinaryEditDoesNotSwapTheDocument() throws {
    var workspace = openDesign()
    #expect(!workspace.undoSwapsDocument)
    try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    #expect(workspace.canUndo)
    #expect(!workspace.undoSwapsDocument)
    workspace.undo()
    #expect(workspace.canRedo)
    #expect(!workspace.redoSwapsDocument)
}

@Test func anEditAfterNewFileIsNotASwap() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    workspace.newFile()
    workspace.addPage()
    #expect(!workspace.undoSwapsDocument)
    workspace.undo()
    #expect(workspace.undoSwapsDocument)
}
