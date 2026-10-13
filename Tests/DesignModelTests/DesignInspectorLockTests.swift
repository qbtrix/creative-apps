// DesignInspectorLockTests.swift: the inspector's X, Y, W and H as undo steps,
// and a lock covering the subtree (#18): a layer inside a locked group refuses
// frame and fill edits, and lockHelp says why. Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1) holds a group (node-2) holding a rectangle (node-3).
private func sample() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(100, 100, 300, 200), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(120, 130, 50, 40), in: "node-2")
    return workspace
}

@Test func aRunOfFrameEditsIsOneUndoStep() throws {
    var workspace = try sample()
    try workspace.setNodeFrame("node-3", x: 121, y: 130, width: 50, height: 40)
    try workspace.setNodeFrame("node-3", x: 122, y: 130, width: 50, height: 40)
    try workspace.setNodeFrame("node-3", x: 122, y: 130, width: 80, height: 40)
    #expect(workspace.frame("node-3") == rc(122, 130, 80, 40))
    workspace.undo()
    #expect(workspace.frame("node-3") == rc(120, 130, 50, 40))
    workspace.redo()
    #expect(workspace.frame("node-3") == rc(122, 130, 80, 40))
}

@Test func aLayerInsideALockedGroupRefusesFrameAndFill() throws {
    var workspace = try sample()
    try workspace.setNodeLocked("node-2", true)
    let before = workspace
    #expect(throws: DesignTreeError.locked("node-3")) {
        try workspace.setNodeFrame("node-3", x: 1, y: 2, width: 3, height: 4)
    }
    #expect(throws: DesignTreeError.locked("node-3")) { try workspace.setFill("node-3", .black) }
    #expect(workspace == before)
}

@Test func unlockingTheGroupFreesTheLayer() throws {
    var workspace = try sample()
    try workspace.setNodeLocked("node-2", true)
    try workspace.setNodeLocked("node-2", false)
    try workspace.setNodeFrame("node-3", x: 1, y: 2, width: 3, height: 4)
    #expect(workspace.frame("node-3") == rc(1, 2, 3, 4))
}

@Test func lockHelpSaysWhichLockStopsTheEdit() throws {
    var workspace = try sample()
    #expect(workspace.lockHelp("node-3") == nil)
    #expect(!workspace.isLockedInTree("node-3"))
    try workspace.setNodeLocked("node-2", true)
    #expect(workspace.isLockedInTree("node-3"))
    #expect(workspace.lockHelp("node-2") == "Unlock the layer to edit it.")
    #expect(workspace.lockHelp("node-3") == "Unlock the group around this layer to edit it.")
    #expect(workspace.lockHelp("node-1") == nil)
    #expect(!workspace.isLockedInTree("nope") && workspace.lockHelp("nope") == nil)
}

@Test func theLockedLayerCanStillBeUnlockedAndHidden() throws {
    var workspace = try sample()
    try workspace.setNodeLocked("node-2", true)
    try workspace.setNodeHidden("node-3", true)
    #expect(workspace.treeNode("node-3")?.isHidden == true)
}
