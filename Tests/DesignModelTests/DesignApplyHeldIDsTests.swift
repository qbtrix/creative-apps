// DesignApplyHeldIDsTests.swift: `apply` rebuilds the held-id index only when an
// edit changes the tree's ids (#2303). `sameIDs` is true exactly when two trees
// hold the same ids in the same places; a style scrub keeps the index as it was,
// and an edit that adds layers still brings the index up to date. Runs on Linux
// and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignApplyHeldIDsTests {
    private func node(_ id: String, _ children: [DesignNode] = [], opacity: Double = 1) -> DesignNode {
        DesignNode(id: id, name: id, kind: children.isEmpty ? .rectangle : .frame,
                   frame: DesignRect(x: 0, y: 0, width: 10, height: 10), children: children, opacity: opacity)
    }

    private var tree: [DesignNode] { [node("f", [node("a"), node("b")]), node("c")] }

    private func allIDs(_ nodes: [DesignNode]) -> Set<String> {
        Set(nodes.flatMap { [$0.id] + allIDs($0.children) })
    }

    @Test func sameIDsIgnoresStyleButNotIDs() {
        let restyled = [node("f", [node("a", opacity: 0.4), node("b")]), node("c", opacity: 0.2)]
        #expect(DesignWorkspace.sameIDs(tree, tree))
        #expect(DesignWorkspace.sameIDs(tree, restyled))
        #expect(!DesignWorkspace.sameIDs(tree, tree + [node("d")]), "a layer added at the end")
        #expect(!DesignWorkspace.sameIDs(tree + [node("d")], tree), "a layer removed from the end")
        #expect(!DesignWorkspace.sameIDs(tree, [node("f", [node("a"), node("b")]), node("e")]), "a top-level id changed")
        #expect(!DesignWorkspace.sameIDs(tree, [node("f", [node("a"), node("x")]), node("c")]), "a nested id changed")
        #expect(!DesignWorkspace.sameIDs(tree, [node("f", [node("a")]), node("c")]), "a nested layer removed")
    }

    @Test func aStyleScrubKeepsTheIndexAndAnAddUpdatesIt() throws {
        var workspace = DesignFixtures.crowd
        workspace.useServices(.live)
        workspace.selectItem("node-2")
        workspace.toggleSelection("node-3")
        let held = workspace.held.ids
        for opacity in [0.5, 0.4, 0.3] { try workspace.setStyle(.opacity(opacity)) }
        #expect(workspace.held.ids == held)
        #expect(workspace.history.undo.map(\.name) == ["Change Opacity"])
        try workspace.run(.duplicate)
        let pages = workspace.pages
        let expected = allIDs(pages.flatMap(\.nodes)).union(pages.map(\.id))
        #expect(expected.count > held.count && workspace.held.ids == expected)
    }
}
