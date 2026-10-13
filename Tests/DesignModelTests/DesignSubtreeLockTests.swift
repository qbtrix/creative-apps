// DesignSubtreeLockTests.swift: a lock covers the node's whole subtree for the
// canvas edits too (#450): a layer inside a locked group can't be resized by its
// handles or by resizeNode, nudged or deleted. Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1) holds a locked group (node-2) holding a selected rectangle (node-3).
private func lockedGroup() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(100, 100, 300, 200), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(120, 130, 50, 40), in: "node-2")
    try workspace.setNodeLocked("node-2", true)
    workspace.selectItem("node-3")
    return workspace
}

@Test func aLayerInsideALockedGroupIsNotDeleted() throws {
    var workspace = try lockedGroup()
    let before = workspace
    workspace.deleteSelection()
    #expect(workspace == before)
    #expect(workspace.treeNode("node-3") != nil)
}

@Test func aLayerInsideALockedGroupIsNotNudged() throws {
    var workspace = try lockedGroup()
    let before = workspace
    workspace.nudge(.right, shift: true)
    #expect(workspace == before)
}

@Test func aLayerInsideALockedGroupShowsNoHandleAndIsNotResized() throws {
    var workspace = try lockedGroup()
    #expect(workspace.handle(at: DesignPoint(x: 170, y: 170)) == nil)
    #expect(throws: DesignTreeError.locked("node-3")) {
        try workspace.resizeNode("node-3", handle: .bottomRight, by: DesignPoint(x: 10, y: 10), shift: false, option: false)
    }
    #expect(workspace.frame("node-3") == rc(120, 130, 50, 40))
    // The press where the handle was is no resize: it picks the unlocked Desktop under it.
    workspace.drag(from: DesignPoint(x: 170, y: 170), to: DesignPoint(x: 200, y: 200))
    workspace.endDrag()
    #expect(workspace.selectedNodeID == "node-1")
    #expect(workspace.frame("node-3") == rc(150, 160, 50, 40))
}

@Test func unlockingTheGroupLetsTheLayerBeDeleted() throws {
    var workspace = try lockedGroup()
    try workspace.setNodeLocked("node-2", false)
    workspace.selectItem("node-3")
    #expect(workspace.handle(at: DesignPoint(x: 170, y: 170)) == .bottomRight)
    workspace.deleteSelection()
    #expect(workspace.treeNode("node-3") == nil)
}
