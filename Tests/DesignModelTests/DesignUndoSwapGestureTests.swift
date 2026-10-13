// DesignUndoSwapGestureTests.swift: undoSwapsDocument and redoSwapsDocument agree
// with whether Undo and Redo actually run (#435). Mid-drag and while editing text
// both are ignored, so neither flag may tell the window to forget its file.
// Runs on Linux and macOS.
import DesignModel
import Testing

@Test func anOpenDragHidesTheUndoSwapAndUndoChangesNothing() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    workspace.newFile()
    #expect(workspace.undoSwapsDocument)
    workspace.selectTool(.rectangle)
    workspace.drag(from: pt(40, 40), to: pt(120, 90))
    #expect(!workspace.undoSwapsDocument, "Undo is ignored mid-drag, so it swaps nothing")
    let pages = workspace.pages
    workspace.undo()
    #expect(workspace.pages == pages)
    workspace.endDrag()
    #expect(workspace.undoActionName == "Undo Add Rectangle")
    workspace.undo()
    #expect(workspace.undoSwapsDocument, "the New File step is next once the drag ends")
}

@Test func anOpenDragHidesTheRedoSwapAndRedoChangesNothing() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    workspace.newFile()
    workspace.undo()
    #expect(workspace.redoSwapsDocument)
    workspace.selectTool(.rectangle)
    workspace.drag(from: pt(300, 300), to: pt(360, 340))
    #expect(!workspace.redoSwapsDocument, "Redo is ignored mid-drag, so it swaps nothing")
    let pages = workspace.pages
    workspace.redo()
    #expect(workspace.pages == pages)
}

@Test func aDragThatNeverStartsKeepsTheSwap() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    workspace.newFile()
    workspace.selectTool(.rectangle)
    workspace.endDrag()
    #expect(workspace.undoSwapsDocument)
}

@Test func editingTextHidesTheRedoSwap() throws {
    var workspace = openDesign()
    workspace.gesture(.text, pt(100, 100), pt(100, 100))
    workspace.setTextDraft("Hello")
    workspace.commitTextEdit()
    workspace.newFile()
    workspace.undo()
    #expect(workspace.redoSwapsDocument)
    try workspace.beginTextEdit("node-2")
    #expect(!workspace.redoSwapsDocument, "Redo is ignored while editing text")
    workspace.commitTextEdit()
    #expect(workspace.redoSwapsDocument)
}
