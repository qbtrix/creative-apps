// DesignTextTests.swift: the Text tool and the inline edit (#199): a click
// places a "Text" node and starts editing it, commit and cancel decide whether
// it stays and what is recorded, setText edits a node directly, and a click
// on an already selected text node edits it. Runs on Linux and macOS.
import DesignModel
import Testing

/// A new file with a text node (node-2) placed by a Text click and committed as "Hello".
private func withHello() -> DesignWorkspace {
    var workspace = openDesign()
    workspace.gesture(.text, pt(100, 100), pt(100, 100))
    workspace.setTextDraft("Hello")
    workspace.commitTextEdit()
    return workspace
}

@Test func aTextClickPlacesATextNodeAndStartsEditingIt() throws {
    var workspace = openDesign()
    workspace.gesture(.text, pt(100, 100), pt(100, 100))
    let node = try #require(workspace.selectedNode)
    #expect(node.kind == .text && node.text == "Text" && node.fill == DesignColor.black)
    #expect(node.frame == rc(100, 100, 120, 24))
    #expect(workspace.editingTextID == node.id && workspace.textDraft == "Text")
    #expect(workspace.treeNode("node-1")?.children.map(\.id) == [node.id])
}

@Test func aNonEmptyCommitRecordsOneAddTextStep() {
    var workspace = openDesign()
    workspace.gesture(.text, pt(100, 100), pt(100, 100))
    #expect(!workspace.canUndo)
    workspace.setTextDraft("Hello")
    workspace.commitTextEdit()
    #expect(workspace.treeNode("node-2")?.text == "Hello")
    #expect(workspace.editingTextID == nil && workspace.textDraft == "")
    #expect(workspace.undoActionName == "Undo Add Text")
    workspace.undo()
    #expect(workspace.treeNode("node-2") == nil && !workspace.canUndo)
    workspace.redo()
    #expect(workspace.treeNode("node-2")?.text == "Hello" && workspace.selectedNodeID == "node-2")
}

@Test func anEmptyCommitRemovesThePlacedNodeAndRecordsNothing() {
    for draft in ["", "   \n"] {
        var workspace = openDesign()
        workspace.gesture(.text, pt(100, 100), pt(100, 100))
        workspace.setTextDraft(draft)
        workspace.commitTextEdit()
        #expect(workspace.treeNode("node-2") == nil)
        #expect(workspace.selectedNodeID == nil && workspace.editingTextID == nil)
        #expect(!workspace.canUndo && !workspace.canRedo)
        #expect(workspace == openDesign())
    }
}

@Test func cancellingThePlacedNodeRestoresTheSelectionBeforeTheClick() {
    var workspace = openDesign()
    workspace.selectItem("node-1")
    workspace.gesture(.text, pt(100, 100), pt(100, 100))
    #expect(workspace.selectedNodeID == "node-2")
    workspace.cancelTextEdit()
    #expect(workspace.treeNode("node-2") == nil && workspace.selectedNodeID == "node-1")
    #expect(workspace.editingTextID == nil && !workspace.canUndo)
}

@Test func setTextChangesOnlyThatNode() throws {
    var workspace = withHello()
    workspace.gesture(.text, pt(300, 300), pt(300, 300))
    workspace.commitTextEdit()
    let before = workspace
    try workspace.setText("node-2", "Bye")
    #expect(workspace.treeNode("node-2")?.text == "Bye")
    #expect(workspace.treeNode("node-3") == before.treeNode("node-3"))
    #expect(workspace.treeNode("node-1")?.frame == before.treeNode("node-1")?.frame)
    #expect(workspace.undoActionName == "Undo Edit Text")
}

@Test func setTextRefusesBadTargetsAndBlankText() throws {
    var workspace = withHello()
    try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    try workspace.setNodeLocked("node-2", true)
    let before = workspace
    #expect(throws: DesignTreeError.locked("node-2")) { try workspace.setText("node-2", "x") }
    #expect(throws: DesignTreeError.notText("node-3")) { try workspace.setText("node-3", "x") }
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.setText("nope", "x") }
    try workspace.setNodeLocked("node-2", false)
    let unlocked = workspace
    #expect(throws: DesignTreeError.emptyText) { try workspace.setText("node-2", "") }
    #expect(throws: DesignTreeError.emptyText) { try workspace.setText("node-2", " \t") }
    #expect(workspace == unlocked)
    #expect(before.treeNode("node-2")?.isLocked == true)
}

@Test func editingAnExistingNodeRecordsEditTextOnlyForARealChange() throws {
    var workspace = withHello()
    try workspace.beginTextEdit("node-2")
    #expect(workspace.editingTextID == "node-2" && workspace.textDraft == "Hello" && workspace.selectedNodeID == "node-2")
    workspace.setTextDraft("Hello")
    workspace.commitTextEdit()
    #expect(workspace.undoActionName == "Undo Add Text")
    try workspace.beginTextEdit("node-2")
    workspace.setTextDraft("")
    workspace.commitTextEdit()
    #expect(workspace.treeNode("node-2")?.text == "Hello" && workspace.undoActionName == "Undo Add Text")
    try workspace.beginTextEdit("node-2")
    workspace.setTextDraft("Hello, world")
    workspace.commitTextEdit()
    #expect(workspace.treeNode("node-2")?.text == "Hello, world")
    #expect(workspace.undoActionName == "Undo Edit Text")
    workspace.undo()
    #expect(workspace.treeNode("node-2")?.text == "Hello")
}

@Test func cancellingAnExistingEditKeepsTheNode() throws {
    var workspace = withHello()
    try workspace.beginTextEdit("node-2")
    workspace.setTextDraft("Gone")
    workspace.cancelTextEdit()
    #expect(workspace.treeNode("node-2")?.text == "Hello" && workspace.editingTextID == nil)
    #expect(workspace.undoActionName == "Undo Add Text")
}

@Test func beginTextEditRefusesUnknownNonTextAndLockedNodes() throws {
    var workspace = withHello()
    try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    try workspace.setNodeLocked("node-2", true)
    let before = workspace
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.beginTextEdit("nope") }
    #expect(throws: DesignTreeError.notText("node-3")) { try workspace.beginTextEdit("node-3") }
    #expect(throws: DesignTreeError.locked("node-2")) { try workspace.beginTextEdit("node-2") }
    #expect(workspace == before)
}

@Test func theDraftIsIgnoredWhenNotEditing() {
    var workspace = withHello()
    let before = workspace
    workspace.setTextDraft("stray")
    workspace.commitTextEdit()
    workspace.cancelTextEdit()
    #expect(workspace == before)
}

@Test func aMoveClickOnAnAlreadySelectedTextNodeBeginsEditing() {
    var workspace = withHello()
    workspace.deselect()
    workspace.gesture(.move, pt(110, 110), pt(110, 110))
    #expect(workspace.selectedNodeID == "node-2" && workspace.editingTextID == nil)
    workspace.drag(from: pt(110, 110), to: pt(110, 110))
    workspace.endDrag()
    #expect(workspace.editingTextID == "node-2" && workspace.textDraft == "Hello")
}

@Test func draggingASelectedTextNodeMovesItInsteadOfEditing() {
    var workspace = withHello()
    workspace.gesture(.move, pt(110, 110), pt(130, 110))
    #expect(workspace.editingTextID == nil)
    #expect(workspace.frame("node-2") == rc(120, 100, 120, 24))
}

@Test func undoAndRedoAreIgnoredWhileEditing() {
    var workspace = withHello()
    workspace.gesture(.text, pt(300, 300), pt(300, 300))
    let editing = workspace
    workspace.undo()
    workspace.redo()
    workspace.nudge(.right, shift: false)
    workspace.deleteSelection()
    #expect(workspace == editing)
    workspace.cancelTextEdit()
    workspace.undo()
    #expect(workspace.treeNode("node-2") == nil)
}

@Test func switchingToolsCommitsTheInlineEdit() {
    var workspace = openDesign()
    workspace.gesture(.text, pt(100, 100), pt(100, 100))
    workspace.setTextDraft("Hi")
    workspace.selectTool(.move)
    #expect(workspace.editingTextID == nil && workspace.treeNode("node-2")?.text == "Hi")
    #expect(workspace.undoActionName == "Undo Add Text")
}

@Test func theNextGestureCommitsTheInlineEditFirst() {
    var workspace = openDesign()
    workspace.gesture(.text, pt(100, 100), pt(100, 100))
    workspace.setTextDraft("One")
    // The tool is back on Move, so this press selects the Desktop frame; it settles the edit first.
    workspace.drag(from: pt(400, 400), to: pt(400, 400))
    workspace.endDrag()
    #expect(workspace.treeNode("node-2")?.text == "One")
    #expect(workspace.editingTextID == nil && workspace.selectedNodeID == "node-1")
    #expect(workspace.treeNode("node-3") == nil)
}

@Test func selectingAnotherRowCommitsTheEdit() {
    var workspace = openDesign()
    workspace.gesture(.text, pt(100, 100), pt(100, 100))
    workspace.setTextDraft("Row")
    workspace.selectItem("node-1")
    #expect(workspace.editingTextID == nil && workspace.treeNode("node-2")?.text == "Row")
    #expect(workspace.selectedNodeID == "node-1")
}
