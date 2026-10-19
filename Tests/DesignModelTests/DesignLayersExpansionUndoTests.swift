// DesignLayersExpansionUndoTests.swift: an open Layers group stays open while
// its own row's eye hides it, and through undo and redo of that step; opening
// or closing a group is never an undo step (#2758, layers-panel L-6). On
// `cards`, Desktop (node-1) holds the group Pair (node-6) with E1 and E2
// (node-7, node-8). Runs on Linux and macOS.
import DesignModel
import Testing

/// `cards` with Desktop and Pair open, so E1 and E2 have rows.
private func openPair() throws -> DesignWorkspace {
    var workspace = DesignFixtures.cards
    try workspace.setExpanded("node-1", true)
    try workspace.setExpanded("node-6", true)
    return workspace
}

@Test func hidingAnOpenGroupFromItsRowKeepsItOpen() throws {
    var workspace = try openPair()
    try workspace.toggleNodeFlag("node-6", .hidden)
    #expect(workspace.treeNode("node-6")?.isHidden == true)
    #expect(workspace.undoActionName == "Undo Hide Layer")
    #expect(workspace.isExpanded("node-6"))
    #expect(workspace.isHiddenInTree("node-7") && workspace.isHiddenInTree("node-8"))
    #expect(workspace.layerRows.map(\.id).contains("node-7"))
}

@Test func undoAndRedoOfTheHideKeepTheGroupOpen() throws {
    var workspace = try openPair()
    try workspace.toggleNodeFlag("node-6", .hidden)
    workspace.undo()
    #expect(workspace.treeNode("node-6")?.isHidden == false)
    #expect(workspace.isExpanded("node-6") && workspace.isExpanded("node-1"))
    #expect(!workspace.isHiddenInTree("node-7"))
    workspace.redo()
    #expect(workspace.treeNode("node-6")?.isHidden == true)
    #expect(workspace.isExpanded("node-6") && workspace.isExpanded("node-1"))
}

@Test func aGroupClosedAfterTheHideStaysClosedThroughUndo() throws {
    var workspace = try openPair()
    try workspace.toggleNodeFlag("node-6", .hidden)
    try workspace.setExpanded("node-6", false)
    workspace.undo()
    #expect(!workspace.isExpanded("node-6"), "undo put back the expansion the hide had")
    #expect(workspace.treeNode("node-6")?.isHidden == false)
}

@Test func openingOrClosingAGroupIsNoUndoStep() throws {
    var workspace = DesignFixtures.cards
    #expect(!workspace.canUndo)
    try workspace.setExpanded("node-1", true)
    try workspace.setExpanded("node-6", true)
    try workspace.setExpanded("node-6", false)
    #expect(!workspace.canUndo)
    #expect(!workspace.isDirty)

    try workspace.toggleNodeFlag("node-6", .hidden)
    try workspace.setExpanded("node-6", true)
    #expect(workspace.undoActionName == "Undo Hide Layer")
    workspace.undo()
    #expect(!workspace.canUndo, "the expansion recorded a step of its own")
    #expect(workspace.isExpanded("node-6"))
}
