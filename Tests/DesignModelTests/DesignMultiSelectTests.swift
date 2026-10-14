// DesignMultiSelectTests.swift: several selected layers (#413, Shift-click):
// Shift-click on the canvas or in Layers adds a layer and takes it out again,
// the last one to join is the primary selection, a plain click replaces the
// set, Escape (deselect) and a click on empty canvas clear it, locked or hidden
// layers can't join, and undo puts back the whole set. Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1) holding three rectangles side by side: node-2, node-3 and node-4, nothing selected.
private func threeRectangles() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(100, 100, 100, 100), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(300, 100, 100, 100), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(500, 100, 100, 100), in: "node-1")
    workspace.deselect()
    return workspace
}

private func click(_ workspace: inout DesignWorkspace, _ x: Double, _ y: Double, shift: Bool = false) {
    workspace.drag(from: pt(x, y), to: pt(x, y), modifiers: shift ? [.shift] : [])
    workspace.endDrag()
}

@Test func shiftClickOnTheCanvasAddsALayerAndThenTakesItOut() throws {
    var workspace = try threeRectangles()
    click(&workspace, 150, 150)
    click(&workspace, 350, 150, shift: true)
    #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
    #expect(workspace.selectedNodeID == "node-3")
    #expect(workspace.hasMultipleSelection)
    click(&workspace, 350, 150, shift: true)
    #expect(workspace.selectedNodeIDs == ["node-2"])
    #expect(workspace.selectedNode?.id == "node-2")
}

@Test func aShiftClickMovesNothingAndRecordsNoStep() throws {
    var workspace = try threeRectangles()
    let undo = workspace.undoActionName
    workspace.selectItem("node-2")
    workspace.drag(from: pt(350, 150), to: pt(350, 150), modifiers: [.shift])
    workspace.drag(from: pt(350, 150), to: pt(400, 200), modifiers: [.shift])
    workspace.endDrag()
    #expect(workspace.frame("node-3") == rc(300, 100, 100, 100))
    #expect(workspace.undoActionName == undo)
}

@Test func thePrimarySelectionIsTheLastToJoin() throws {
    var workspace = try threeRectangles()
    workspace.toggleSelection("node-4")
    workspace.toggleSelection("node-2")
    #expect(workspace.selectedNodeID == "node-2")
    workspace.toggleSelection("node-2")
    #expect(workspace.selectedNodeID == "node-4")
    #expect(workspace.selectedNodes.map(\.id) == ["node-4"])
}

@Test func aPlainClickReplacesTheSelectionAndEscapeOrEmptyCanvasClearIt() throws {
    var workspace = try threeRectangles()
    workspace.toggleSelection("node-2")
    workspace.toggleSelection("node-3")
    click(&workspace, 550, 150)
    #expect(workspace.selectedNodeIDs == ["node-4"])
    workspace.toggleSelection("node-3")
    workspace.deselect()
    #expect(workspace.selectedNodeIDs.isEmpty)
    workspace.toggleSelection("node-2")
    workspace.toggleSelection("node-3")
    click(&workspace, -50, -50)  // off the page, past the Desktop frame
    #expect(workspace.selectedNodeIDs.isEmpty)
    #expect(workspace.selectedNodeID == nil)
}

@Test func lockedOrHiddenLayersCannotJoin() throws {
    var workspace = try threeRectangles()
    try workspace.addNode(.group, frame: rc(100, 400, 300, 200), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(120, 420, 50, 50), in: "node-5")
    try workspace.setNodeLocked("node-2", true)
    try workspace.setNodeHidden("node-3", true)
    try workspace.setNodeLocked("node-5", true)
    workspace.selectItem("node-4")
    for id in ["node-2", "node-3", "node-6", "page-1", "node-99"] {
        workspace.toggleSelection(id)
        #expect(!workspace.canAddToSelection(id))
    }
    try workspace.setNodeLocked("node-5", false)
    try workspace.setNodeHidden("node-5", true)
    workspace.toggleSelection("node-6")
    #expect(workspace.selectedNodeIDs == ["node-4"])
}

@Test func severalSelectedLayersShowNoHandlesAndAreNotNudgedOrDeleted() throws {
    var workspace = try threeRectangles()
    workspace.toggleSelection("node-2")
    workspace.toggleSelection("node-3")
    let before = workspace
    #expect(workspace.handle(at: pt(400, 200)) == nil)
    workspace.nudge(.right, shift: false)
    workspace.deleteSelection()
    #expect(workspace == before)
    #expect(workspace.selectionBounds == rc(100, 100, 300, 100))
}

@Test func undoPutsBackTheWholeSelection() throws {
    var workspace = try threeRectangles()
    workspace.toggleSelection("node-2")
    workspace.toggleSelection("node-3")
    try workspace.setFill("node-4", DesignColor(1, 2, 3))
    workspace.deselect()
    workspace.undo()
    #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
}

@Test func layersShiftClickTogglesOnlyTheClickedRow() throws {
    var workspace = try threeRectangles()
    workspace.selectRows(["node-4"], shift: false)
    #expect(workspace.selectedNodeIDs == ["node-4"])
    // Rows run frontmost first: node-4, node-3, node-2. The list extends a range to node-2.
    workspace.selectRows(["node-4", "node-3", "node-2"], shift: true)
    #expect(workspace.selectedNodeIDs == ["node-4", "node-2"])
    // Shift-click on node-2 again: the list drops it.
    workspace.selectRows(["node-4"], shift: true)
    #expect(workspace.selectedNodeIDs == ["node-4"])
}

@Test func layersCommandClickKeepsTheRowsThatCanJoin() throws {
    var workspace = try threeRectangles()
    try workspace.setNodeLocked("node-3", true)
    workspace.selectRows(["node-2"], shift: false)
    workspace.selectRows(["node-2", "node-3", "node-4"], shift: false)
    #expect(workspace.selectedNodeIDs == ["node-2", "node-4"])
    workspace.selectRows([], shift: false)
    #expect(workspace.selectedNodeIDs.isEmpty)
    workspace.selectRows(["page-1"], shift: false)
    #expect(workspace.selectedPageID == "page-1")
}
