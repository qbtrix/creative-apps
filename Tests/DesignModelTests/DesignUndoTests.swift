// DesignUndoTests.swift: the model-owned undo history (#201): one named step
// per edit, selection coming back with it, ids never reused, drags and
// coalesced runs as one step, file and page edits undoable, and refused calls
// recording nothing. Runs on Linux and macOS.
import DesignModel
import Testing

@Test func addingARectangleThenUndoRemovesItAndRestoresTheEarlierSelection() throws {
    var workspace = openDesign()
    workspace.selectItem("node-1")
    let id = try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    #expect(workspace.undoActionName == "Undo Add Rectangle" && workspace.redoActionName == "Redo")
    workspace.undo()
    #expect(workspace.treeNode(id) == nil)
    #expect(workspace.selectedNodeID == "node-1")
    #expect(workspace.redoActionName == "Redo Add Rectangle" && workspace.undoActionName == "Undo")
    workspace.redo()
    #expect(workspace.treeNode(id)?.frame == rc(10, 10, 50, 50) && workspace.selectedNodeID == id)
}

@Test func undoOfAMoveRestoresTheExactFrame() throws {
    var workspace = openDesign()
    let id = try workspace.addNode(.rectangle, frame: rc(10.25, 20.5, 50, 50), in: "node-1")
    try workspace.move(id, by: pt(10, 0))
    #expect(workspace.frame(id) == rc(20.25, 20.5, 50, 50))
    workspace.undo()
    #expect(workspace.frame(id) == rc(10.25, 20.5, 50, 50))
    workspace.redo()
    #expect(workspace.frame(id) == rc(20.25, 20.5, 50, 50))
}

@Test func resizeAndTextEditsUndoExactly() throws {
    var workspace = openDesign()
    let id = try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    try workspace.resizeNode(id, handle: .bottomRight, by: pt(7, 9), shift: false, option: false)
    workspace.undo()
    #expect(workspace.frame(id) == rc(10, 10, 50, 50))
    var text = openDesign()
    text.gesture(.text, pt(20, 20), pt(20, 20))
    text.setTextDraft("First")
    text.commitTextEdit()
    try text.setText("node-2", "Second")
    text.undo()
    #expect(text.treeNode("node-2")?.text == "First")
    text.undo()
    #expect(text.treeNode("node-2") == nil)
}

@Test func oneDragIsOneStep() {
    var workspace = openDesign()
    workspace.selectTool(.rectangle)
    workspace.drag(from: pt(40, 40), to: pt(100, 100))
    workspace.endDrag()
    workspace.selectTool(.move)
    for x in 50...90 { workspace.drag(from: pt(60, 60), to: pt(Double(x), 70)) }
    workspace.endDrag()
    #expect(workspace.undoActionName == "Undo Move")
    workspace.undo()
    #expect(workspace.undoActionName == "Undo Add Rectangle")
    workspace.undo()
    #expect(!workspace.canUndo)
}

@Test func anUndoneAddNeverGivesItsIDToTheNextNode() throws {
    var workspace = openDesign()
    let first = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    workspace.undo()
    let second = try workspace.addNode(.ellipse, frame: rc(0, 0, 10, 10), in: "node-1")
    #expect(first == "node-2" && second == "node-3")
    workspace.undo()
    workspace.redo()
    #expect(workspace.treeNode("node-3")?.kind == .ellipse)
    workspace.addPage()
    workspace.undo()
    workspace.addPage()
    #expect(workspace.pages.map(\.id) == ["page-1", "page-3"])
}

@Test func deletePageUndoesAndRedoes() throws {
    var workspace = openDesign()
    workspace.addPage()
    try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10))
    let before = workspace.pages
    try workspace.deletePage("page-2")
    #expect(workspace.undoActionName == "Undo Delete Page" && workspace.selectedPageID == "page-1")
    workspace.undo()
    #expect(workspace.pages == before)
    #expect(workspace.selectedPageID == "page-2" && workspace.selectedNodeID == "node-3")
    workspace.redo()
    #expect(workspace.pages.map(\.id) == ["page-1"] && workspace.selectedPageID == "page-1")
}

@Test func newFileOverAnOpenFileUndoesBackToTheOldFile() throws {
    var workspace = openDesign()
    workspace.addPage()
    try workspace.addNode(.text, frame: rc(5, 5, 50, 20))
    let (pages, page, node) = (workspace.pages, workspace.selectedPageID, workspace.selectedNodeID)
    workspace.newFile()
    #expect(workspace.pages.map(\.id) == ["page-1"] && workspace.undoActionName == "Undo New File")
    workspace.undo()
    #expect(workspace.pages == pages && workspace.selectedPageID == page && workspace.selectedNodeID == node)
    // The new file's ids restarted, but undoing back to the old file must not hand out its ids again.
    workspace.addPage()
    #expect(workspace.pages.map(\.id) == ["page-1", "page-2", "page-3"])
}

@Test func theFirstNewFileHasNothingToUndo() {
    let workspace = openDesign()
    #expect(!workspace.canUndo)
}

@Test func aCoalescedRunOfFrameChangesIsOneStep() throws {
    var workspace = openDesign()
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    for width in stride(from: 11.0, through: 40, by: 1) { try workspace.setNodeFrame(id, x: 0, y: 0, width: width, height: 10) }
    #expect(workspace.undoActionName == "Undo Change Frame")
    workspace.undo()
    #expect(workspace.frame(id) == rc(0, 0, 10, 10))
    #expect(workspace.undoActionName == "Undo Add Rectangle")
}

@Test func aFrameRunOnAnotherNodeStartsANewStep() throws {
    var workspace = openDesign()
    let a = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    let b = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    try workspace.setNodeFrame(a, x: 1, y: 1, width: 10, height: 10)
    try workspace.setNodeFrame(b, x: 2, y: 2, width: 10, height: 10)
    try workspace.setNodeFrame(a, x: 3, y: 3, width: 10, height: 10)
    workspace.undo()
    workspace.undo()
    workspace.undo()
    #expect(workspace.frame(a) == rc(0, 0, 10, 10) && workspace.frame(b) == rc(0, 0, 10, 10))
    #expect(workspace.undoActionName == "Undo Add Rectangle")
}

@Test func anUndoBreaksTheRunSoALaterEditIsItsOwnStep() throws {
    var workspace = openDesign()
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    try workspace.setNodeFrame(id, x: 5, y: 0, width: 10, height: 10)
    try workspace.move(id, by: pt(1, 1))
    try workspace.setNodeFrame(id, x: 9, y: 0, width: 10, height: 10)
    workspace.undo()
    workspace.undo()
    try workspace.setNodeFrame(id, x: 7, y: 0, width: 10, height: 10)
    workspace.undo()
    #expect(workspace.frame(id) == rc(5, 0, 10, 10))
}

@Test func refusedCallsRecordNothing() throws {
    var workspace = openDesign()
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    try workspace.setNodeLocked(id, true)
    let before = workspace
    _ = try? workspace.addNode(.rectangle, frame: rc(0, 0, 1, 1), in: "nope")
    _ = try? workspace.addNode(.rectangle, frame: rc(0, 0, 1, 1), in: id)
    _ = try? workspace.moveNode("nope", into: nil)
    _ = try? workspace.moveNode("node-1", into: id)
    _ = try? workspace.renameNode(id, to: "  ")
    _ = try? workspace.renamePage("nope", to: "x")
    _ = try? workspace.renamePage("page-1", to: "")
    _ = try? workspace.setNodeHidden("nope", true)
    _ = try? workspace.setNodeLocked("nope", true)
    _ = try? workspace.move(id, by: pt(1, 1))
    _ = try? workspace.setFill(id, .black)
    _ = try? workspace.setNodeFrame(id, x: 1, y: 1, width: 1, height: 1)
    _ = try? workspace.resizeNode(id, handle: .top, by: pt(0, 1), shift: false, option: false)
    _ = try? workspace.deletePage("page-1")
    _ = try? workspace.deletePage("nope")
    _ = try? workspace.setExpanded("nope", true)
    #expect(workspace == before)
}

@Test func editsThatChangeNothingRecordNothing() throws {
    var workspace = openDesign()
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    let before = workspace
    try workspace.renameNode(id, to: "Rectangle")
    try workspace.renamePage("page-1", to: "Page 1")
    try workspace.setNodeHidden(id, false)
    try workspace.setNodeLocked(id, false)
    try workspace.moveNode(id, into: "node-1")
    try workspace.setFill(id, DesignNodeKind.rectangle.defaultFill)
    workspace.deselect()
    workspace.selectItem("node-1")
    #expect(workspace.pages == before.pages)
    #expect(workspace.undoActionName == "Undo Add Rectangle")
    workspace.undo()
    #expect(workspace.treeNode(id) == nil)
}

@Test func everyDocumentEditIsNamed() throws {
    var workspace = openDesign()
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    try workspace.renameNode(id, to: "Card")
    #expect(workspace.undoActionName == "Undo Rename Layer")
    try workspace.setNodeHidden(id, true)
    #expect(workspace.undoActionName == "Undo Hide Layer")
    try workspace.setNodeHidden(id, false)
    #expect(workspace.undoActionName == "Undo Show Layer")
    try workspace.setNodeLocked(id, true)
    #expect(workspace.undoActionName == "Undo Lock Layer")
    try workspace.setNodeLocked(id, false)
    #expect(workspace.undoActionName == "Undo Unlock Layer")
    try workspace.moveNode(id, into: nil)
    #expect(workspace.undoActionName == "Undo Move Layer")
    try workspace.renamePage("page-1", to: "Home")
    #expect(workspace.undoActionName == "Undo Rename Page")
    workspace.addPage()
    #expect(workspace.undoActionName == "Undo Add Page")
}

@Test func aNewEditClearsRedoAndTheHistoryKeepsAHundredSteps() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    workspace.undo()
    #expect(workspace.canRedo)
    workspace.addPage()
    #expect(!workspace.canRedo)
    for _ in 0..<150 { workspace.addPage() }
    var steps = 0
    while workspace.canUndo {
        workspace.undo()
        steps += 1
    }
    #expect(steps == 100)
}

@Test func undoAndRedoAreIgnoredMidDrag() {
    var workspace = openDesign()
    workspace.addPage()
    workspace.selectTool(.rectangle)
    workspace.drag(from: pt(0, 0), to: pt(50, 50))
    let mid = workspace
    workspace.undo()
    workspace.redo()
    #expect(workspace == mid)
    workspace.endDrag()
    workspace.undo()
    #expect(workspace.treeNode("node-3") == nil)
}
