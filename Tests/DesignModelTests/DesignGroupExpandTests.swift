// DesignGroupExpandTests.swift: after Group the new group's own Layers row is
// expanded, so its members stay in the visible rows (copy-group D0-3a, #2471),
// and a canvas click on a group's child opens the rows around it so the child's
// row shows (J9, #6198), on DesignFixtures' `cards` through `.live`. Runs on
// Linux and macOS.
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

    /// J9 (#6198): picking E1 on the canvas, with every row collapsed, opens Desktop and Pair so E1's
    /// row shows one level under Pair's. A plain click picks Pair (the outermost group, AR-14); a
    /// ⌘-press picks E1 at once, and a double-click enters Pair and picks E1.
    @Test(arguments: [true, false]) func pickingAGroupsChildOnTheCanvasRevealsItsRow(deep: Bool) throws {
        var workspace = DesignFixtures.cards
        workspace.useServices(.live)
        #expect(!workspace.layerRows.map(\.id).contains("node-7"))
        let point = DesignPoint(x: 950, y: 450)
        func press(_ modifiers: DesignModifiers) {
            workspace.drag(from: point, to: point, modifiers: modifiers)
            workspace.endDrag()
        }
        if deep { press(.deep) } else {
            press([])
            #expect(workspace.selectedNodeIDs == ["node-6"])
            press(.enter)
        }
        #expect(workspace.selectedNodeIDs == ["node-7"])
        let rows = workspace.layerRows
        let pair = try #require(rows.first { $0.id == "node-6" })
        let e1 = try #require(rows.first { $0.id == "node-7" })
        #expect(e1.depth == pair.depth + 1)
    }
}
