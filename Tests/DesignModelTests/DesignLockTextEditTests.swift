// DesignLockTextEditTests.swift: a lock on a layer with an open text edit on it or
// inside it commits the edit first, so the typing survives as its own step (#613).
// Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1) holds a group (node-2) holding a text layer (node-3) and a rectangle
/// (node-4), with node-3 open for editing and "Typed" in the editor.
private func typingInAGroup() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(100, 100, 300, 200), in: "node-1")
    try workspace.addNode(.text, frame: rc(120, 130, 80, 20), in: "node-2")
    try workspace.addNode(.rectangle, frame: rc(220, 130, 80, 40), in: "node-2")
    try workspace.beginTextEdit("node-3")
    workspace.setTextDraft("Typed")
    return workspace
}

@Test func lockingTheGroupMidEditKeepsTheTyping() throws {
    var workspace = try typingInAGroup()
    try workspace.setNodeLocked("node-2", true)
    #expect(workspace.treeNode("node-3")?.text == "Typed")
    #expect(workspace.treeNode("node-2")?.isLocked == true)
    #expect(workspace.editingTextID == nil)
    #expect(workspace.undoActionName == "Undo Lock Layer")
    workspace.undo()
    #expect(workspace.treeNode("node-2")?.isLocked == false)
    #expect(workspace.undoActionName == "Undo Edit Text")
    workspace.undo()
    #expect(workspace.treeNode("node-3")?.text == "Text")
}

@Test func lockingTheEditedLayerItselfKeepsTheTyping() throws {
    var workspace = try typingInAGroup()
    try workspace.toggleNodeFlag("node-3", .locked)
    #expect(workspace.treeNode("node-3")?.text == "Typed")
    #expect(workspace.treeNode("node-3")?.isLocked == true)
    #expect(workspace.editingTextID == nil)
    #expect(workspace.undoActionName == "Undo Lock Layer")
}

@Test func lockingTheOuterFrameMidEditKeepsTheTyping() throws {
    var workspace = try typingInAGroup()
    try workspace.setNodeLocked("node-1", true)
    #expect(workspace.treeNode("node-3")?.text == "Typed")
    #expect(workspace.editingTextID == nil)
}

@Test func lockingASiblingLeavesTheEditOpen() throws {
    var workspace = try typingInAGroup()
    try workspace.setNodeLocked("node-4", true)
    #expect(workspace.editingTextID == "node-3")
    #expect(workspace.textDraft == "Typed")
    workspace.commitTextEdit()
    #expect(workspace.treeNode("node-3")?.text == "Typed")
    #expect(workspace.undoActionName == "Undo Edit Text")
}
