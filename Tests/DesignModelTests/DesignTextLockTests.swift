// DesignTextLockTests.swift: the inline text edit follows the subtree lock (#535).
// A text layer inside a locked group can't start an edit, so Return's begin-edit
// and commit path changes nothing and records no step. Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1) holds a locked group (node-2) holding a selected text layer (node-3).
private func lockedGroupWithText() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(100, 100, 300, 200), in: "node-1")
    try workspace.addNode(.text, frame: rc(120, 130, 80, 20), in: "node-2")
    try workspace.setNodeLocked("node-2", true)
    workspace.selectItem("node-3")
    return workspace
}

@Test func aTextLayerInsideALockedGroupCannotBeRetyped() throws {
    var workspace = try lockedGroupWithText()
    let before = workspace
    #expect(throws: DesignTreeError.locked("node-3")) { try workspace.beginTextEdit("node-3") }
    #expect(workspace.editingTextID == nil)
    workspace.setTextDraft("Changed")
    workspace.commitTextEdit()
    #expect(workspace.treeNode("node-3")?.text == "Text")
    #expect(workspace.undoActionName == before.undoActionName)
    #expect(workspace == before)
}

@Test func unlockingTheGroupLetsTheTextBeRetyped() throws {
    var workspace = try lockedGroupWithText()
    try workspace.setNodeLocked("node-2", false)
    try workspace.beginTextEdit("node-3")
    workspace.setTextDraft("Changed")
    workspace.commitTextEdit()
    #expect(workspace.treeNode("node-3")?.text == "Changed")
    #expect(workspace.undoActionName == "Undo Edit Text")
}
