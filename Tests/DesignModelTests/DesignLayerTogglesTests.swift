// DesignLayerTogglesTests.swift: the eye and lock toggles on a Layers row
// (#45): a click flips the node's own flag as one undo step, and a row inside
// a hidden or locked group shows that state. Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1) holds a group (node-2) holding a rectangle (node-3).
private func sample() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(100, 100, 300, 200), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(120, 130, 50, 40), in: "node-2")
    return workspace
}

@Test(arguments: DesignLayerFlag.allCases)
func aToggleClickIsOneUndoStep(flag: DesignLayerFlag) throws {
    var workspace = try sample()
    let before = workspace.treeNode("node-3")
    try workspace.toggleNodeFlag("node-3", flag)
    let after = try #require(workspace.treeNode("node-3"))
    #expect(flag == .hidden ? after.isHidden : after.isLocked)
    #expect(workspace.layerToggles("node-3").first { $0.flag == flag }?.isOn == true)
    workspace.undo()
    #expect(workspace.treeNode("node-3") == before)
    try workspace.toggleNodeFlag("node-3", flag)
    try workspace.toggleNodeFlag("node-3", flag)
    #expect(workspace.treeNode("node-3") == before)
}

@Test func aLockedLayerCanStillBeToggled() throws {
    var workspace = try sample()
    try workspace.setNodeLocked("node-2", true)
    try workspace.toggleNodeFlag("node-3", .hidden)
    try workspace.toggleNodeFlag("node-2", .locked)
    #expect(workspace.treeNode("node-3")?.isHidden == true && workspace.treeNode("node-2")?.isLocked == false)
}

@Test func anUnknownIDThrowsAndHasNoToggles() throws {
    var workspace = try sample()
    let before = workspace
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.toggleNodeFlag("nope", .hidden) }
    #expect(workspace == before)
    #expect(workspace.layerToggles("nope").isEmpty)
    #expect(!workspace.isHiddenInTree("nope"))
}

@Test func aPlainRowShowsAnOpenEyeAndLock() throws {
    let toggles = try sample().layerToggles("node-3")
    #expect(toggles.map(\.flag) == [.hidden, .locked])
    #expect(toggles.map(\.isOn) == [false, false])
    #expect(toggles.map(\.offSymbol) == ["eye", "lock.open"])
    #expect(toggles.map(\.title) == ["Hide Layer", "Lock Layer"])
}

@Test func aChildRowShowsItsGroupsHiddenAndLockedState() throws {
    var workspace = try sample()
    try workspace.setNodeHidden("node-2", true)
    try workspace.setNodeLocked("node-2", true)
    #expect(workspace.isHiddenInTree("node-3") && !workspace.isHiddenInTree("node-1"))
    let child = workspace.layerToggles("node-3")
    #expect(child.map(\.isOn) == [false, false])
    #expect(child.map(\.offSymbol) == ["eye.slash", "lock"])
    #expect(child.map(\.title) == ["Hide Layer (its group is hidden)", "Lock Layer (its group is locked)"])
    let group = workspace.layerToggles("node-2")
    #expect(group.map(\.isOn) == [true, true])
    #expect(group.map(\.title) == ["Show Layer", "Unlock Layer"])
}
