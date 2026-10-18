// DesignGroupExpandTests.swift: after Group the new group's own Layers row is
// expanded, so its members stay in the visible rows (copy-group D0-3a, #2471),
// on DesignFixtures' `cards` through `.live`. Runs on Linux and macOS.
@testable import DesignModel
import Testing

// cards: Desktop node-1 holds A node-2, B node-3, C node-4, Title node-5, Pair node-6 (E1 node-7,
// E2 node-8), Locked node-9 and Hidden node-10, back to front.
@Suite struct DesignGroupExpandTests {
    /// `cards` on `.live` with `selection` selected, primary last.
    private func open(selecting selection: [String]) -> DesignWorkspace {
        var workspace = DesignFixtures.cards
        workspace.useServices(.live)
        for (index, id) in selection.enumerated() {
            if index == 0 { workspace.selectItem(id) } else { workspace.toggleSelection(id) }
        }
        return workspace
    }

    @Test func groupExpandsTheNewGroupAndShowsItsMembers() throws {
        var workspace = open(selecting: ["node-2", "node-3"])
        try workspace.run(.group)
        #expect(workspace.selectedNodeIDs.count == 1)
        let group = try #require(workspace.selectedNodeIDs.first)
        #expect(workspace.isExpanded(group))
        let rows = workspace.layerRows.map(\.id)
        let at = try #require(rows.firstIndex(of: group))
        // Layers lists front to back, so B (node-3) shows above A (node-2), one level deeper.
        #expect(Array(rows.dropFirst(at + 1).prefix(2)) == ["node-3", "node-2"])
        let depth = try #require(workspace.layerRows.first { $0.id == group }?.depth)
        #expect(workspace.layerRows.filter { ["node-2", "node-3"].contains($0.id) }.allSatisfy { $0.depth == depth + 1 })
    }

    @Test func ungroupExpandsNoMember() throws {
        var workspace = open(selecting: ["node-6"])
        try workspace.run(.ungroup)
        #expect(workspace.selectedNodeIDs == ["node-7", "node-8"])
        #expect(!workspace.isExpanded("node-7") && !workspace.isExpanded("node-8"))
    }
}
