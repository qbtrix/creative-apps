// DesignCanvasClickTests.swift: a Move-tool click on the canvas (#17): it selects the
// topmost visible, unlocked node without touching the document or the undo stack, and the
// Layers rows open down to the node it picked. Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1) holds a rectangle (node-2) and, over it, an ellipse (node-3); nothing selected.
private func stacked() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(100, 100, 200, 100), in: "node-1")
    try workspace.addNode(.ellipse, frame: rc(150, 120, 200, 100), in: "node-1")
    workspace.deselect()
    return workspace
}

@Test func aClickSelectsTheTopmostNodeAndLeavesNoUndoStep() throws {
    var workspace = try stacked()
    let pages = workspace.pages
    workspace.gesture(.move, pt(160, 130), pt(160, 130))
    #expect(workspace.selectedNodeID == "node-3")
    #expect(workspace.pages == pages)
    #expect(workspace.undoActionName == "Undo Add Ellipse")
    // Undo takes back the last edit, not the click.
    workspace.undo()
    #expect(workspace.treeNode("node-3") == nil)
}

@Test func aClickGoesThroughHiddenAndLockedNodes() throws {
    var workspace = try stacked()
    try workspace.setNodeHidden("node-3", true)
    workspace.gesture(.move, pt(160, 130), pt(160, 130))
    #expect(workspace.selectedNodeID == "node-2")
    try workspace.setNodeLocked("node-2", true)
    workspace.gesture(.move, pt(160, 130), pt(160, 130))
    #expect(workspace.selectedNodeID == "node-1")
}

@Test func aClickOnANestedNodeOpensItsLayersRows() throws {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(300, 300, 200, 200), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(320, 320, 50, 50), in: "node-2")
    workspace.deselect()
    try workspace.setExpanded("node-1", false)
    #expect(!workspace.layerRows.contains { $0.id == "node-3" })
    workspace.gesture(.move, pt(330, 330), pt(330, 330))
    #expect(workspace.selectedNodeID == "node-3")
    #expect(workspace.layerRows.map(\.id) == ["node-1", "node-2", "node-3"])
}

@Test func aDragThatMovesStillMakesOneMoveStep() throws {
    var workspace = try stacked()
    workspace.gesture(.move, pt(160, 130), pt(170, 140))
    #expect(workspace.frame("node-3") == rc(160, 130, 200, 100))
    #expect(workspace.undoActionName == "Undo Move")
    workspace.undo()
    #expect(workspace.frame("node-3") == rc(150, 120, 200, 100))
    #expect(workspace.undoActionName == "Undo Add Ellipse")
}
