// DesignGroupTests.swift: LiveGrouping, the live Group and Ungroup (copy-group
// C-2, #416 (a), blueprint 5.4), on DesignFixtures' `cards` through `.live`.
// Group makes "Group N" (the lowest free N) whose frame is the union, at the
// topmost member's place, and moves no leaf (QD-V4); Ungroup puts the children
// back in order where the group was; a cross-parent Group and an Ungroup of a
// non-group are refused and change nothing. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import Testing

// cards: Desktop node-1 holds A node-2, B node-3, C node-4, Title node-5, Pair node-6 (E1 node-7,
// E2 node-8), Locked node-9 and Hidden node-10, back to front.
private enum ID {
    static let desktop = "node-1", a = "node-2", b = "node-3", c = "node-4", title = "node-5", pair = "node-6"
    static let e1 = "node-7", e2 = "node-8"
}

/// `cards` on `.live` with `selection` selected, primary last.
private func open(selecting selection: [String]) -> DesignWorkspace {
    var workspace = DesignFixtures.cards
    workspace.useServices(.live)
    for (index, id) in selection.enumerated() {
        if index == 0 { workspace.selectItem(id) } else { workspace.toggleSelection(id) }
    }
    return workspace
}

/// Desktop's children, back to front.
private func desktop(_ workspace: DesignWorkspace) -> [DesignNode] {
    workspace.selectedPage?.nodes.node(ID.desktop)?.children ?? []
}

/// Every leaf's id and frame, so a test can say nothing moved.
private func leafFrames(_ nodes: [DesignNode]) -> [String: DesignRect] {
    var out: [String: DesignRect] = [:]
    for node in nodes {
        if node.children.isEmpty { out[node.id] = node.frame } else { out.merge(leafFrames(node.children)) { $1 } }
    }
    return out
}

@Suite struct DesignGroupTests {
    let original = desktop(DesignFixtures.cards)

    @Test func groupMovesNothing() throws {
        var workspace = open(selecting: [ID.a, ID.b])
        try workspace.run(.group)
        let made = try #require(desktop(workspace).first)
        #expect(made.kind == .group && made.name == "Group 1")
        #expect(made.frame == rc(100, 100, 400, 120))  // A (100, 100, 100, 80) with B (300, 140, 200, 80)
        #expect(made.children.map(\.id) == [ID.a, ID.b])
        #expect(desktop(workspace).map(\.id) == [made.id, ID.c, ID.title, ID.pair, "node-9", "node-10"])
        #expect(leafFrames(workspace.selectedPage?.nodes ?? []) == leafFrames(DesignFixtures.cards.selectedPage?.nodes ?? []))
        #expect(workspace.selectedNodeIDs == [made.id])
        #expect(workspace.undoActionName == "Undo Group" && workspace.history.undo.count == 1)
    }

    @Test func groupTakesTheTopmostMembersPlace() throws {
        var workspace = open(selecting: [ID.c, ID.a])
        try workspace.run(.group)
        let ids = desktop(workspace).map(\.id)
        #expect(ids.count == original.count - 1)
        let made = try #require(desktop(workspace).dropFirst().first)
        #expect(ids.first == ID.b && made.kind == .group)
        #expect(made.children.map(\.id) == [ID.a, ID.c])  // sibling order, not selection order
        #expect(Array(ids.dropFirst(2)) == [ID.title, ID.pair, "node-9", "node-10"])
    }

    @Test func aSecondGroupIsGroup2() throws {
        var workspace = open(selecting: [ID.a, ID.b])
        try workspace.run(.group)
        workspace.selectItem(ID.c)
        workspace.toggleSelection(ID.title)
        try workspace.run(.group)
        let names = desktop(workspace).filter { $0.kind == .group }.map(\.name)
        #expect(names == ["Group 1", "Group 2", "Pair"])
    }

    @Test func ungroupRestoresOrderAndPositions() throws {
        var workspace = open(selecting: [ID.a, ID.b])
        try workspace.run(.group)
        try workspace.run(.ungroup)
        #expect(desktop(workspace) == original)
        #expect(workspace.selectedNodeIDs == [ID.a, ID.b])
        #expect(workspace.undoActionName == "Undo Ungroup" && workspace.history.undo.count == 2)
    }

    @Test func ungroupMovesNothing() throws {
        var workspace = open(selecting: [ID.pair])
        try workspace.run(.ungroup)
        #expect(desktop(workspace).map(\.id) == [ID.a, ID.b, ID.c, ID.title, ID.e1, ID.e2, "node-9", "node-10"])
        #expect(leafFrames(workspace.selectedPage?.nodes ?? []) == leafFrames(DesignFixtures.cards.selectedPage?.nodes ?? []))
        #expect(workspace.selectedNodeIDs == [ID.e1, ID.e2])
    }

    @Test func groupAcrossParentsIsRefused() throws {
        var workspace = open(selecting: [ID.a, ID.e1])
        #expect(workspace.selectedNodeIDs == [ID.a, ID.e1])
        let before = workspace
        #expect(workspace.help(.group) == "Select layers that share a parent.")
        #expect(throws: DesignRefusal.notSameParent) { try workspace.run(.group) }
        #expect(workspace == before && workspace.history.undo.isEmpty)
        let page = try #require(before.selectedPage)
        var mint = DesignIDMint(taken: [], after: 10)
        #expect(throws: DesignRefusal.notSameParent) { try LiveGrouping().group([ID.a, ID.e1], on: page, mint: &mint) }
        #expect(mint.minted.isEmpty)
    }

    @Test func movingTheGroupMovesBothChildren() throws {
        var workspace = open(selecting: [ID.a, ID.b])
        try workspace.run(.group)
        let page = try #require(workspace.selectedPage)
        let made = try #require(desktop(workspace).first)
        let moved = try LiveTransforming().move([made.id], by: pt(5, 5), on: page)
        let group = try #require(moved.nodes.node(made.id))
        #expect(group.frame == rc(105, 105, 400, 120))
        #expect(group.children.map(\.frame) == [rc(105, 105, 100, 80), rc(305, 145, 200, 80)])
    }

    @Test func undoRestoresTheTreeAndSelection() throws {
        var workspace = open(selecting: [ID.a, ID.b])
        let before = workspace.pages
        try workspace.run(.group)
        workspace.undo()
        #expect(workspace.pages == before)
        #expect(workspace.selectedNodeIDs == [ID.a, ID.b])
    }

    @Test func aSavedGroupReopens() throws {
        var workspace = open(selecting: [ID.a, ID.b])
        try workspace.run(.group)
        var reopened = DesignWorkspace()
        try reopened.open(workspace.fileData())
        #expect(reopened.pages == workspace.pages)
        #expect(desktop(reopened).first?.name == "Group 1")
    }

    @Test func ungroupOnALeafIsRefused() throws {
        var workspace = open(selecting: [ID.a])
        let before = workspace
        #expect(workspace.help(.ungroup) == "A isn't a group.")
        #expect(throws: DesignRefusal.notAGroup("A")) { try workspace.run(.ungroup) }
        #expect(workspace == before)
        let page = try #require(before.selectedPage)
        #expect(throws: DesignRefusal.notAGroup("A")) { try LiveGrouping().ungroup([ID.a], on: page) }
    }

    @Test func helpLawHoldsOnLive() throws {
        let page = try #require(DesignFixtures.cards.selectedPage)
        let law = DesignContractLaw.check(.live, on: page)
        #expect(law.violations.isEmpty, "\(law.violations)")
    }
}
