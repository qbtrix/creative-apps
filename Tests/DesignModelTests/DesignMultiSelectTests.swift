// DesignMultiSelectTests.swift: Shift-click adds a layer to the selection or
// takes it out (#413, slice 1). A plain click still replaces the selection, the
// last layer added is the primary one single-selection callers read, Escape and
// a click on empty canvas clear it, and a locked or hidden layer (or one inside a
// locked or hidden group) is never added. Runs on Linux and macOS.
import DesignModel
import Testing

/// A new file with three rectangles side by side on its Desktop frame: node-2, node-3, node-4.
private func threeRectangles() -> DesignWorkspace {
    var workspace = openDesign()
    for x in [100.0, 400, 700] { workspace.gesture(.rectangle, pt(x, 100), pt(x + 200, 300)) }
    workspace.deselect()
    return workspace
}

@Test func shiftClickOnTheCanvasAddsThenRemovesALayer() {
    var workspace = threeRectangles()
    workspace.gesture(.move, pt(150, 150), pt(150, 150))
    workspace.gesture(.move, pt(450, 150), pt(450, 150), .shift)
    #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
    #expect(workspace.selectedNodeID == "node-3")
    #expect(workspace.hasMultipleSelection)
    workspace.gesture(.move, pt(150, 150), pt(150, 150), .shift)
    #expect(workspace.selectedNodeIDs == ["node-3"])
    #expect(workspace.selectedNode?.id == "node-3")
    #expect(!workspace.hasMultipleSelection)
    // Selecting is not an edit.
    #expect(workspace.undoActionName == "Undo Add Rectangle")
}

@Test func aShiftDragOnALayerMovesNothing() {
    var workspace = threeRectangles()
    workspace.selectItem("node-2")
    workspace.gesture(.move, pt(450, 150), pt(500, 200), .shift)
    #expect(workspace.frame("node-3") == rc(400, 100, 200, 200))
    #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
}

@Test func aPlainClickReplacesTheSelection() {
    var workspace = threeRectangles()
    workspace.toggleSelection("node-2")
    workspace.toggleSelection("node-3")
    workspace.gesture(.move, pt(750, 150), pt(750, 150))
    #expect(workspace.selectedNodeIDs == ["node-4"])
    workspace.toggleSelection("node-2")
    workspace.selectItem("node-3")
    #expect(workspace.selectedNodeIDs == ["node-3"])
}

@Test func theLastLayerAddedIsThePrimaryUntilItLeaves() {
    var workspace = threeRectangles()
    for id in ["node-4", "node-2", "node-3"] { workspace.toggleSelection(id) }
    #expect(workspace.selectedNodeID == "node-3")
    workspace.toggleSelection("node-3")
    #expect(workspace.selectedNodeID == "node-2")
    #expect(workspace.selectedNodes.map(\.id) == ["node-4", "node-2"])
}

@Test func escapeAndAClickOnEmptyCanvasClearTheSelection() {
    var workspace = threeRectangles()
    workspace.toggleSelection("node-2")
    workspace.toggleSelection("node-3")
    workspace.deselect()
    #expect(workspace.selectedNodeIDs.isEmpty && workspace.selectedNodeID == nil)
    workspace.toggleSelection("node-2")
    workspace.toggleSelection("node-3")
    // Off the Desktop frame, on the bare page.
    workspace.gesture(.move, pt(1500, 1100), pt(1500, 1100))
    #expect(workspace.selectedNodeIDs.isEmpty)
}

@Test func lockedAndHiddenLayersAreNeverAdded() throws {
    var workspace = threeRectangles()
    try workspace.setNodeLocked("node-3", true)
    try workspace.setNodeHidden("node-4", true)
    workspace.toggleSelection("node-2")
    workspace.toggleSelection("node-3")
    workspace.toggleSelection("node-4")
    #expect(workspace.selectedNodeIDs == ["node-2"])
}

@Test func layersInsideALockedOrHiddenGroupAreNeverAdded() throws {
    var workspace = threeRectangles()
    let locked = try workspace.addNode(.frame, frame: rc(100, 500, 300, 300))
    let lockedChild = try workspace.addNode(.rectangle, frame: rc(120, 520, 50, 50), in: locked)
    let hidden = try workspace.addNode(.frame, frame: rc(500, 500, 300, 300))
    let hiddenChild = try workspace.addNode(.rectangle, frame: rc(520, 520, 50, 50), in: hidden)
    try workspace.setNodeLocked(locked, true)
    try workspace.setNodeHidden(hidden, true)
    workspace.selectItem("node-2")
    workspace.toggleSelection(lockedChild)
    workspace.toggleSelection(hiddenChild)
    workspace.toggleSelection("no-such-node")
    #expect(workspace.selectedNodeIDs == ["node-2"])
}

@Test func aSelectedLayerThatWasLockedCanStillBeTakenOut() throws {
    var workspace = threeRectangles()
    workspace.toggleSelection("node-2")
    workspace.toggleSelection("node-3")
    try workspace.setNodeLocked("node-3", true)
    workspace.toggleSelection("node-3")
    #expect(workspace.selectedNodeIDs == ["node-2"])
}

@Test func theBoundsCoverEverySelectedLayer() {
    var workspace = threeRectangles()
    #expect(workspace.selectionBounds == nil)
    workspace.toggleSelection("node-2")
    #expect(workspace.selectionBounds == rc(100, 100, 200, 200))
    workspace.toggleSelection("node-4")
    #expect(workspace.selectionBounds == rc(100, 100, 800, 200))
}

/// Nudge and Delete act on several layers (#2463, DesignCanvasTests); Align to the page stays one layer's.
@Test func severalSelectedLayersShowNoHandlesAndRefuseSingleLayerAlign() {
    var workspace = threeRectangles()
    workspace.toggleSelection("node-2")
    workspace.toggleSelection("node-3")
    #expect(workspace.handle(at: pt(600, 300)) == nil)
    #expect(workspace.multipleSelectionHelp != nil)
    #expect(workspace.alignHelp(.left) == workspace.multipleSelectionHelp)
}

@Test func undoRestoresTheWholeSelectionAnEditHad() throws {
    var workspace = threeRectangles()
    workspace.toggleSelection("node-2")
    workspace.toggleSelection("node-3")
    try workspace.renameNode("node-4", to: "Third")
    workspace.deselect()
    workspace.undo()
    #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
}

@Test func collapsingAGroupDropsTheSelectedLayersItHides() throws {
    var workspace = threeRectangles()
    let frame = try workspace.addNode(.frame, frame: rc(100, 500, 300, 300))
    let child = try workspace.addNode(.rectangle, frame: rc(120, 520, 50, 50), in: frame)
    workspace.selectItem("node-2")
    workspace.toggleSelection(child)
    try workspace.setExpanded(frame, false)
    #expect(workspace.selectedNodeIDs == ["node-2"])
    // With only the hidden layer selected, collapsing selects the group, as before (#121).
    try workspace.setExpanded(frame, true)
    workspace.selectItem(child)
    try workspace.setExpanded(frame, false)
    #expect(workspace.selectedNodeIDs == [frame])
}
