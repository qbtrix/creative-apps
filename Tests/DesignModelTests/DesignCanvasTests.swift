// DesignCanvasTests.swift: selecting and moving on the canvas (#17): hit
// testing order and what it skips, moving a node and its subtree by a delta or a
// Move-tool drag, nudging, and locked nodes holding still. Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1) holds a rectangle (node-2) and, on top of it, an overlapping ellipse (node-3).
private func overlapping() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(100, 100, 200, 100), in: "node-1")
    try workspace.addNode(.ellipse, frame: rc(150, 120, 200, 100), in: "node-1")
    workspace.deselect()
    return workspace
}

/// Desktop holds a group (node-2) with one child rectangle (node-3) inside it.
private func grouped() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(300, 300, 200, 200), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(320, 320, 50, 50), in: "node-2")
    workspace.deselect()
    return workspace
}

@Test func theTopmostNodeWinsAndTheDesktopIsTheBackstop() throws {
    let workspace = try overlapping()
    #expect(workspace.hitTest(pt(160, 130)) == "node-3")
    #expect(workspace.hitTest(pt(110, 110)) == "node-2")
    #expect(workspace.hitTest(pt(5, 5)) == "node-1")
    #expect(workspace.hitTest(pt(-5, -5)) == nil)
    #expect(workspace.hitTest(pt(1500, 500)) == nil)
}

@Test func edgesCountAsInside() throws {
    let workspace = try overlapping()
    #expect(workspace.hitTest(pt(100, 100)) == "node-2")
    #expect(workspace.hitTest(pt(350, 220)) == "node-3")
}

@Test func aChildIsHitBeforeItsGroupAndTheGroupWhereTheChildIsNot() throws {
    let workspace = try grouped()
    #expect(workspace.hitTest(pt(330, 330)) == "node-3")
    #expect(workspace.hitTest(pt(480, 480)) == "node-2")
}

@Test func hiddenNodesAreSkippedWithTheirSubtree() throws {
    var workspace = try overlapping()
    try workspace.setNodeHidden("node-3", true)
    #expect(workspace.hitTest(pt(160, 130)) == "node-2")
    var nested = try grouped()
    try nested.setNodeHidden("node-2", true)
    #expect(nested.hitTest(pt(330, 330)) == "node-1")
    try nested.setNodeHidden("node-1", true)
    #expect(nested.hitTest(pt(330, 330)) == nil)
}

@Test func lockedNodesAreSkippedWithTheirSubtree() throws {
    var workspace = try overlapping()
    try workspace.setNodeLocked("node-3", true)
    #expect(workspace.hitTest(pt(160, 130)) == "node-2")
    var nested = try grouped()
    try nested.setNodeLocked("node-2", true)
    #expect(nested.hitTest(pt(330, 330)) == "node-1")
    try nested.setNodeLocked("node-1", true)
    #expect(nested.hitTest(pt(330, 330)) == nil)
}

@Test func hitTestUsesTheSelectedPageOnly() throws {
    var workspace = try overlapping()
    workspace.addPage()
    #expect(workspace.hitTest(pt(160, 130)) == "node-4")
    workspace.selectPage("page-1")
    #expect(workspace.hitTest(pt(160, 130)) == "node-3")
    #expect(DesignWorkspace().hitTest(pt(1, 1)) == nil)
}

@Test func moveShiftsANodeAndItsWholeSubtree() throws {
    var workspace = try grouped()
    try workspace.move("node-2", by: pt(10, -5))
    #expect(workspace.frame("node-2") == rc(310, 295, 200, 200))
    #expect(workspace.frame("node-3") == rc(330, 315, 50, 50))
    #expect(workspace.frame("node-1") == rc(0, 0, 1440, 1024))
    #expect(workspace.undoActionName == "Undo Move")
}

@Test func aMoveToolDragSelectsAndMovesTheNodeUnderThePointer() throws {
    var workspace = try overlapping()
    workspace.gesture(.move, pt(110, 110), pt(130, 125))
    #expect(workspace.selectedNodeID == "node-2")
    #expect(workspace.frame("node-2") == rc(120, 115, 200, 100))
    #expect(workspace.frame("node-3") == rc(150, 120, 200, 100))
    #expect(workspace.undoActionName == "Undo Move")
}

@Test func draggingAGroupCarriesItsChildren() throws {
    var workspace = try grouped()
    workspace.gesture(.move, pt(480, 480), pt(490, 470))
    #expect(workspace.selectedNodeID == "node-2")
    #expect(workspace.frame("node-2") == rc(310, 290, 200, 200))
    #expect(workspace.frame("node-3") == rc(330, 310, 50, 50))
}

@Test func aMoveToolClickOnNothingDeselects() throws {
    var workspace = try overlapping()
    workspace.selectItem("node-2")
    let before = workspace.pages
    workspace.gesture(.move, pt(-20, -20), pt(-20, -20))
    #expect(workspace.selectedNodeID == nil)
    #expect(workspace.pages == before)
    #expect(workspace.undoActionName == "Undo Add Ellipse")
}

@Test func aLockedNodeDoesNotMove() throws {
    var workspace = try overlapping()
    try workspace.setNodeLocked("node-3", true)
    let before = workspace
    #expect(throws: DesignTreeError.locked("node-3")) { try workspace.move("node-3", by: pt(10, 10)) }
    #expect(workspace == before)
    // The drag goes through the locked node to what is behind it.
    workspace.gesture(.move, pt(160, 130), pt(180, 150))
    #expect(workspace.frame("node-3") == rc(150, 120, 200, 100))
    #expect(workspace.selectedNodeID == "node-2")
    #expect(workspace.frame("node-2") == rc(120, 120, 200, 100))
}

@Test func moveRefusesUnknownIDsAndIgnoresNonFiniteDeltas() throws {
    var workspace = try overlapping()
    let before = workspace
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.move("nope", by: pt(1, 1)) }
    try workspace.move("node-2", by: pt(.nan, 4))
    try workspace.move("node-2", by: pt(0, 0))
    #expect(workspace == before)
}

@Test func nudgeMovesTheSelectionByOneOrTenWithShift() throws {
    var workspace = try overlapping()
    workspace.selectItem("node-2")
    workspace.nudge(.right, shift: false)
    workspace.nudge(.down, shift: false)
    #expect(workspace.frame("node-2") == rc(101, 101, 200, 100))
    workspace.nudge(.left, shift: true)
    workspace.nudge(.up, shift: true)
    #expect(workspace.frame("node-2") == rc(91, 91, 200, 100))
}

@Test func aRunOfNudgesToOneNodeIsOneUndoStepNamedNudge() throws {
    var workspace = try overlapping()
    workspace.selectItem("node-2")
    for _ in 0..<5 { workspace.nudge(.right, shift: false) }
    #expect(workspace.undoActionName == "Undo Nudge")
    workspace.undo()
    #expect(workspace.frame("node-2") == rc(100, 100, 200, 100))
    #expect(workspace.undoActionName == "Undo Add Ellipse")
}

@Test func nudgeDoesNothingForALockedNodeOrNoSelection() throws {
    var workspace = try overlapping()
    let none = workspace
    workspace.nudge(.right, shift: false)
    #expect(workspace == none)
    try workspace.setNodeLocked("node-2", true)
    workspace.selectItem("node-2")
    let locked = workspace
    workspace.nudge(.right, shift: true)
    #expect(workspace == locked)
}

@Test func deleteSelectionRemovesTheNodeAndItsSubtreeAsOneStep() throws {
    var workspace = try grouped()
    workspace.selectItem("node-2")
    workspace.deleteSelection()
    #expect(workspace.treeNode("node-2") == nil && workspace.treeNode("node-3") == nil)
    #expect(workspace.selectedNodeID == nil)
    #expect(workspace.undoActionName == "Undo Delete Group")
    workspace.undo()
    #expect(workspace.treeNode("node-3")?.frame == rc(320, 320, 50, 50))
    #expect(workspace.selectedNodeID == "node-2")
}

@Test func deleteSelectionSkipsLockedAndUnselected() throws {
    var workspace = try overlapping()
    let none = workspace
    workspace.deleteSelection()
    #expect(workspace == none)
    try workspace.setNodeLocked("node-2", true)
    workspace.selectItem("node-2")
    let locked = workspace
    workspace.deleteSelection()
    #expect(workspace == locked)
}

/// `cards` with A (node-2) and B (node-3) marqueed, on the live services the app ships with.
private func marqueedAAndB() -> DesignWorkspace {
    var workspace = DesignFixtures.cards
    workspace.drag(from: pt(80, 80), to: pt(520, 240))
    workspace.endDrag()
    return workspace
}

// #2463: the canvas keys call nudge and deleteSelection; with several layers selected they act.
@Test func theCanvasArrowKeysNudgeSeveralSelectedLayersAsOneNudgeStep() throws {
    var workspace = marqueedAAndB()
    #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
    let a = try #require(workspace.frame("node-2")), b = try #require(workspace.frame("node-3"))
    let previous = workspace.undoActionName
    workspace.nudge(.right, shift: true)
    workspace.nudge(.down, shift: false)
    #expect(workspace.frame("node-2") == rc(a.x + 10, a.y + 1, a.width, a.height))
    #expect(workspace.frame("node-3") == rc(b.x + 10, b.y + 1, b.width, b.height))
    #expect(workspace.undoActionName == "Undo Nudge")
    workspace.undo()
    #expect(workspace.frame("node-2") == a && workspace.frame("node-3") == b)
    #expect(workspace.undoActionName == previous)
}

@Test func theCanvasDeleteKeyAndEditDeleteRemoveSeveralSelectedLayersAsOneDeleteStep() {
    var workspace = marqueedAAndB()
    #expect(workspace.help(.delete) == nil)
    workspace.deleteSelection()
    #expect(workspace.treeNode("node-2") == nil && workspace.treeNode("node-3") == nil)
    #expect(workspace.selectedNodeIDs.isEmpty)
    #expect(workspace.undoActionName == "Undo Delete")
    workspace.undo()
    #expect(workspace.treeNode("node-2") != nil && workspace.treeNode("node-3") != nil)
    #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
}
