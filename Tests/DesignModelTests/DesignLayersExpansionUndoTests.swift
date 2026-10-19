// DesignLayersExpansionUndoTests.swift: the expanded Layers rows are the
// workspace's, not the document's (layers-panel L-6, #2758). A group opened
// with setExpanded stays open through a document edit, its undo and redo, and
// a group opened after an edit stays open when that edit is undone. An id that
// leaves the page stays in the set and is ignored: ids are never reused in a
// file, so it opens nothing else, and undoing the delete brings the group back
// open. Runs on Linux and macOS.
import DesignModel
import Testing

@Suite struct DesignLayersExpansionUndoTests {
    /// `cards`: Desktop (node-1) holds A, B, C, Title, Pair (node-6: E1 node-7, E2 node-8), Locked, Hidden.
    let desktop = "node-1", pair = "node-6", e1 = "node-7", e2 = "node-8"

    /// `cards` with Desktop and Pair open, so Pair's children show.
    func openPair() throws -> DesignWorkspace {
        var workspace = DesignFixtures.cards
        try workspace.setExpanded(desktop, true)
        try workspace.setExpanded(pair, true)
        return workspace
    }

    @Test func anOpenGroupStaysOpenThroughHideUndoAndRedo() throws {
        var workspace = try openPair()
        #expect(workspace.expandedNodeIDs == [desktop, pair])

        try workspace.toggleNodeFlag(pair, .hidden)
        #expect(workspace.undoActionName == "Undo Hide Layer")
        #expect(workspace.isHiddenInTree(e1) && workspace.isHiddenInTree(e2))
        #expect(workspace.isExpanded(pair))
        #expect(workspace.layerRows.map(\.id).contains(e1))

        workspace.undo()
        #expect(!workspace.isHiddenInTree(e1))
        #expect(workspace.isExpanded(pair))
        workspace.redo()
        #expect(workspace.isHiddenInTree(e1))
        #expect(workspace.expandedNodeIDs == [desktop, pair])
    }

    @Test func undoKeepsAGroupOpenedAfterTheEdit() throws {
        var workspace = DesignFixtures.cards
        try workspace.setExpanded(desktop, true)
        try workspace.toggleNodeFlag(pair, .hidden)
        try workspace.setExpanded(pair, true)

        workspace.undo()
        #expect(workspace.isExpanded(pair), "undo put back the expanded rows from before the edit")
        #expect(workspace.layerRows.map(\.id).contains(e2))
    }

    @Test func undoKeepsAGroupClosedAfterTheEdit() throws {
        var workspace = try openPair()
        try workspace.toggleNodeFlag(pair, .hidden)
        try workspace.setExpanded(pair, false)

        workspace.undo()
        #expect(!workspace.isExpanded(pair), "undo reopened a group closed after the edit")
    }

    @Test func aDeletedGroupsIDIsIgnoredAndComesBackOpenOnUndo() throws {
        var workspace = try openPair()
        workspace.selectItem(pair)
        workspace.deleteSelection()
        #expect(workspace.undoActionName == "Undo Delete Group")
        #expect(!workspace.layerRows.map(\.id).contains(pair))
        // Kept, not pruned: nothing shows it, and setExpanded refuses the id while it is gone.
        #expect(workspace.isExpanded(pair))
        #expect(throws: DesignTreeError.unknownID(pair)) { try workspace.setExpanded(pair, false) }

        workspace.undo()
        #expect(workspace.layerRows.map(\.id).contains(e1), "Pair came back closed after undoing its delete")
    }
}
