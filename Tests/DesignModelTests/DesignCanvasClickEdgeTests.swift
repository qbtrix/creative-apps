// DesignCanvasClickEdgeTests.swift: edge cases for the Move tool's click and drag on the
// canvas (#17, #446): a drag that comes back to where it started, a handle press that never
// moves, a group dragged with hidden and locked children, a non-finite pointer, a click that
// commits a text edit, and a seeded run of clicks that never adds an undo step. Runs on Linux
// and macOS.
import DesignModel
import Testing

/// Desktop (node-1) holds a group (node-2, 300 300 200 200) whose children are a rectangle
/// (node-3, 320 320 50 50) and an ellipse (node-4, 400 400 60 60); nothing selected.
private func grouped() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(300, 300, 200, 200), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(320, 320, 50, 50), in: "node-2")
    try workspace.addNode(.ellipse, frame: rc(400, 400, 60, 60), in: "node-2")
    workspace.deselect()
    return workspace
}

@Test func aDragThatComesBackToItsStartLeavesNoUndoStep() throws {
    var workspace = try grouped()
    let pages = workspace.pages
    workspace.selectTool(.move)
    workspace.drag(from: pt(330, 330), to: pt(380, 360))
    workspace.drag(from: pt(380, 360), to: pt(330, 330))
    workspace.endDrag()
    #expect(workspace.selectedNodeID == "node-3")
    #expect(workspace.pages == pages)
    #expect(workspace.undoActionName == "Undo Add Ellipse")
}

@Test func aHandlePressThatNeverMovesLeavesNoUndoStep() throws {
    var workspace = try grouped()
    workspace.selectItem("node-3")
    let pages = workspace.pages
    #expect(workspace.handle(at: pt(370, 370)) == .bottomRight)
    workspace.gesture(.move, pt(370, 370), pt(370, 370))
    #expect(workspace.pages == pages)
    #expect(workspace.selectedNodeID == "node-3")
    #expect(workspace.undoActionName == "Undo Add Ellipse")
}

@Test func draggingAGroupMovesItsHiddenAndLockedChildrenAndUndoPutsThemBack() throws {
    var workspace = try grouped()
    try workspace.setNodeHidden("node-3", true)
    try workspace.setNodeLocked("node-4", true)
    let pages = workspace.pages
    // The press lands on the group itself: node-3 is hidden and node-4 is elsewhere.
    workspace.gesture(.move, pt(480, 310), pt(500, 340))
    #expect(workspace.selectedNodeID == "node-2")
    #expect(workspace.frame("node-2") == rc(320, 330, 200, 200))
    #expect(workspace.frame("node-3") == rc(340, 350, 50, 50))
    #expect(workspace.frame("node-4") == rc(420, 430, 60, 60))
    #expect(workspace.undoActionName == "Undo Move")
    workspace.undo()
    #expect(workspace.pages == pages)
}

@Test func aNonFinitePointerNeitherSelectsNorMoves() throws {
    var workspace = try grouped()
    let pages = workspace.pages
    workspace.selectTool(.move)
    workspace.drag(from: pt(.nan, 330), to: pt(330, 330))
    workspace.drag(from: pt(330, 330), to: pt(.infinity, 330))
    workspace.endDrag()
    #expect(workspace.selectedNodeID == nil)
    #expect(workspace.pages == pages)
    // A finite pointer move after a non-finite one inside a started gesture still counts.
    workspace.drag(from: pt(330, 330), to: pt(330, 330))
    workspace.drag(from: pt(330, 330), to: pt(.nan, .nan))
    workspace.drag(from: pt(330, 330), to: pt(340, 335))
    workspace.endDrag()
    #expect(workspace.frame("node-3") == rc(330, 325, 50, 50))
    #expect(workspace.undoActionName == "Undo Move")
}

@Test func aClickOnAnotherNodeCommitsTheTextBeingEdited() throws {
    var workspace = try grouped()
    workspace.gesture(.text, pt(700, 700), pt(700, 700))
    let text = try #require(workspace.editingTextID)
    workspace.setTextDraft("Hi")
    workspace.gesture(.move, pt(330, 330), pt(330, 330))
    #expect(workspace.editingTextID == nil)
    #expect(workspace.treeNode(text)?.text == "Hi")
    #expect(workspace.selectedNodeID == "node-3")
    #expect(workspace.undoActionName == "Undo Add Text")
}

@Test func lockingTheSelectionStopsArrowKeysAndHandles() throws {
    var workspace = try grouped()
    workspace.selectItem("node-3")
    try workspace.setNodeLocked("node-3", true)
    let pages = workspace.pages
    workspace.nudge(.right, shift: true)
    #expect(workspace.handle(at: pt(370, 370)) == nil)
    // The press goes past the locked rectangle to the group under it.
    workspace.gesture(.move, pt(330, 330), pt(330, 330))
    #expect(workspace.selectedNodeID == "node-2")
    #expect(workspace.pages == pages)
}

@Test func seededClicksNeverChangeTheDocumentOrTheUndoStack() throws {
    var workspace = try grouped()
    let pages = workspace.pages
    var generator = SplitMix(seed: 0x17_446)
    for _ in 0..<500 {
        let point = pt(Double(generator.next() % 800), Double(generator.next() % 800))
        workspace.gesture(.move, point, point)
        #expect(workspace.selectedNodeID == workspace.hitTest(point))
    }
    #expect(workspace.pages == pages)
    #expect(workspace.undoActionName == "Undo Add Ellipse")
}

/// A small deterministic generator, so the seeded run is the same on every machine.
private struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

