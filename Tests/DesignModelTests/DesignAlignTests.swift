// DesignAlignTests.swift: Object > Align for the single selected layer (#417,
// slice 1): each edge inside the parent frame or the page, a layer in a group
// aligning to the frame around the group, one named undo step per command, no
// drift on repeats, and the reasons a command is off. Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1, 0 0 1440 1024) holds a 400 × 300 frame (node-2) at 100, 50
/// holding a 40 × 20 rectangle (node-3) at 150, 80, which is selected.
private func sample() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.frame, frame: rc(100, 50, 400, 300), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(150, 80, 40, 20), in: "node-2")
    return workspace
}

@Test(arguments: [
    (DesignAlignEdge.left, rc(100, 80, 40, 20)),
    (.center, rc(280, 80, 40, 20)),
    (.right, rc(460, 80, 40, 20)),
    (.top, rc(150, 50, 40, 20)),
    (.middle, rc(150, 190, 40, 20)),
    (.bottom, rc(150, 330, 40, 20)),
])
func eachEdgeAlignsTheLayerInsideItsParentFrame(edge: DesignAlignEdge, expected: DesignRect) throws {
    var workspace = try sample()
    workspace.alignLayer(edge)
    #expect(workspace.frame("node-3") == expected)
    #expect(workspace.undoActionName == "Undo \(edge.title)")
}

@Test func aTopLevelLayerAlignsToThePage() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 20, 100, 50))
    workspace.alignLayer(.right)
    workspace.alignLayer(.bottom)
    #expect(workspace.frame("node-2") == rc(1340, 974, 100, 50))
}

@Test func aLayerInAGroupAlignsToTheFrameAroundTheGroup() throws {
    var workspace = openDesign()
    try workspace.addNode(.frame, frame: rc(0, 0, 400, 400), in: "node-1")
    try workspace.addNode(.group, frame: rc(50, 50, 100, 100), in: "node-2")
    try workspace.addNode(.rectangle, frame: rc(60, 60, 20, 20), in: "node-3")
    #expect(workspace.alignBounds("node-4") == rc(0, 0, 400, 400))
    workspace.alignLayer(.right)
    #expect(workspace.frame("node-4") == rc(380, 60, 20, 20))
}

@Test func aligningAFrameMovesItsChildrenWithIt() throws {
    var workspace = try sample()
    workspace.selectItem("node-2")
    workspace.alignLayer(.left)
    #expect(workspace.frame("node-2") == rc(0, 50, 400, 300))
    #expect(workspace.frame("node-3") == rc(50, 80, 40, 20))
}

@Test func eachCommandIsOneUndoStep() throws {
    var workspace = try sample()
    workspace.alignLayer(.left)
    workspace.alignLayer(.top)
    #expect(workspace.frame("node-3") == rc(100, 50, 40, 20))
    workspace.undo()
    #expect(workspace.frame("node-3") == rc(100, 80, 40, 20))
    #expect(workspace.undoActionName == "Undo Align Left")
    workspace.undo()
    #expect(workspace.frame("node-3") == rc(150, 80, 40, 20))
    workspace.redo()
    #expect(workspace.frame("node-3") == rc(100, 80, 40, 20))
}

@Test func repeatedCenteringNeverDrifts() throws {
    var workspace = openDesign()
    try workspace.addNode(.frame, frame: rc(0.1, 0.2, 333.3, 77.7), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(3, 4, 10.01, 9.99), in: "node-2")
    workspace.alignLayer(.center)
    workspace.alignLayer(.middle)
    let aligned = try #require(workspace.frame("node-3"))
    #expect(abs(aligned.x + aligned.width / 2 - (0.1 + 333.3 / 2)) < 1e-9)
    for _ in 0..<10 {
        workspace.alignLayer(.center)
        workspace.alignLayer(.middle)
    }
    #expect(workspace.frame("node-3") == aligned)
    #expect(workspace.alignHelp(.center) == "The layer is already centered.")
}

@Test func alignHelpSaysWhyACommandCantRun() throws {
    var workspace = try sample()
    #expect(DesignAlignEdge.allCases.allSatisfy { workspace.alignHelp($0) == nil })
    workspace.alignLayer(.left)
    #expect(workspace.alignHelp(.left) == "The layer is already at the left edge.")
    #expect(workspace.alignHelp(.right) == nil)
    #expect(workspace.alignHelps == [.left: "The layer is already at the left edge."])

    workspace.deselect()
    #expect(workspace.alignHelp(.top) == "Select a layer to align it.")
    #expect(DesignWorkspace().alignHelp(.top) == "Select a layer to align it.")

    workspace.selectItem("node-3")
    try workspace.setNodeLocked("node-3", true)
    #expect(workspace.alignHelp(.top) == "Unlock the layer to edit it.")
    try workspace.setNodeLocked("node-3", false)
    try workspace.setNodeLocked("node-2", true)
    workspace.selectItem("node-3")
    #expect(workspace.alignHelp(.top) == "Unlock the group around this layer to edit it.")
    try workspace.setNodeLocked("node-2", false)
    try workspace.setNodeHidden("node-2", true)
    workspace.selectItem("node-3")
    #expect(workspace.alignHelp(.top) == "Show the group around this layer to align it.")
}

@Test func alignWaitsForAnInlineTextEditToFinish() throws {
    var workspace = openDesign()
    let text = try workspace.addNode(.text, frame: rc(10, 10, 120, 24), in: "node-1")
    try workspace.beginTextEdit(text)
    #expect(workspace.alignHelp(.left) == "Finish editing the text first.")
    workspace.alignLayer(.left)
    #expect(workspace.frame(text) == rc(10, 10, 120, 24))
}

@Test func aCommandThatCantRunChangesNothing() throws {
    var workspace = try sample()
    try workspace.setNodeLocked("node-2", true)
    workspace.selectItem("node-3")
    var before = workspace
    workspace.alignLayer(.left)
    #expect(workspace == before)

    workspace = try sample()
    workspace.alignLayer(.top)
    before = workspace
    workspace.alignLayer(.top)
    #expect(workspace == before)
}
