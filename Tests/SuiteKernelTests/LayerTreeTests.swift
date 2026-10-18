// LayerTreeTests.swift (editor-kernel EK-11, slice EK-tree, KJ3): the one
// layer tree's rules, written before its body. It nests and finds nodes, lists
// panel rows front to back, cascades hide and lock to descendants, moves a
// layer into a parent at a clamped index with refusals (unknown, into itself
// or a descendant, not a container, locked), arranges among siblings, groups,
// ungroups keeping order and duplicates with fresh ids. Every check waits on
// EK-12, which writes the body and turns them on (docs/factory/lead.md rule 13).
import Testing
import SuiteKernel

/// A small payload for hand-built trees: a container flag and nothing else.
private struct TreeItem: LayerPayload {
    var holdsChildren: Bool
}

/// A leaf layer for a hand-built tree.
private func leaf(_ id: String, locked: Bool = false) -> LayerNode<TreeItem> {
    LayerNode(id: id, name: id.uppercased(), isLocked: locked, payload: TreeItem(holdsChildren: false))
}

/// A group layer for a hand-built tree.
private func group(_ id: String, _ children: [LayerNode<TreeItem>]) -> LayerNode<TreeItem> {
    LayerNode(id: id, name: id.uppercased(), children: children, payload: TreeItem(holdsChildren: true))
}

/// The refusal `body` throws, nil when it throws none. The tree's edits throw
/// only `TreeRefusal`; the closure is untyped so it infers inside `#expect`.
private func refusal(_ body: () throws -> Void) -> TreeRefusal? {
    do {
        try body()
        return nil
    } catch {
        return error as? TreeRefusal
    }
}

/// A mint that hands out "m1", "m2", ... in order.
private struct Mint {
    var count = 0
    mutating func next() -> String {
        count += 1
        return "m\(count)"
    }
}

@Suite struct LayerTreeTests {
    /// Roots a, b, c, d back to front: d is the front.
    private static let flat = LayerTree([leaf("a"), leaf("b"), leaf("c"), leaf("d")])

    private static func rootIDs(_ tree: LayerTree<TreeItem>) -> [String] { tree.roots.map(\.id) }

    @Test(.disabled("waits on EK-12")) func nestsAndFindsNodes() {
        let tree = KernelFixtures.tree200
        #expect(tree.node("card-7")?.name == "Card 7")
        #expect(tree.node("row-2-col-3")?.children.count == 9)
        #expect(tree.node("nowhere") == nil)
        #expect(tree.ancestors(of: "item-2-3-4") == ["gallery", "row-2", "row-2-col-3"])
        #expect(tree.ancestors(of: "header") == [])
        #expect(tree.ancestors(of: "nowhere") == nil)
        #expect(tree.frontToBack.count == 200)
        #expect(Set(tree.frontToBack).count == 200)
    }

    @Test(.disabled("waits on EK-12")) func rowsAndOrderFrontToBack() {
        let tree = KernelFixtures.tree200
        #expect(tree.rows(expanded: []).map(\.id)
            == ["background", "footer", "archive", "gallery", "cards", "hero", "header"])
        let open = tree.rows(expanded: ["header"])
        #expect(open.map(\.id).suffix(4) == ["header", "header-3", "header-2", "header-1"])
        #expect(open.last?.depth == 1 && open.first(where: { $0.id == "header" })?.isExpanded == true)
        let nested = LayerTree([leaf("a"), group("g", [leaf("x"), leaf("y")]), leaf("d")])
        #expect(nested.frontToBack == ["d", "g", "y", "x", "a"])
    }

    @Test(.disabled("waits on EK-12")) func hiddenCascades() {
        var tree = KernelFixtures.tree200
        #expect(tree.isEffectivelyHidden("archive"))
        #expect(tree.isEffectivelyHidden("archive-3"))
        #expect(!tree.isEffectivelyHidden("card-1"))
        // Two levels below the hidden node, not only its own children.
        #expect(tree.update("gallery") { $0.isHidden = true })
        #expect(tree.isEffectivelyHidden("item-1-1-1"))
        #expect(tree.node("item-1-1-1")?.isHidden == false)
        let row = tree.rows(expanded: ["archive"]).first { $0.id == "archive-1" }
        #expect(row?.inheritsHidden == true && row?.isHidden == false)
    }

    @Test(.disabled("waits on EK-12")) func lockedCascades() {
        var tree = KernelFixtures.tree200
        #expect(tree.isEffectivelyLocked("footer-4"))
        #expect(!tree.isEffectivelyLocked("hero-1"))
        #expect(tree.update("row-3") { $0.isLocked = true })
        #expect(tree.isEffectivelyLocked("item-3-2-5"))
        #expect(!tree.isEffectivelyLocked("item-2-2-5"))
    }

    @Test(.disabled("waits on EK-12")) func updateEditsInPlace() {
        var tree = KernelFixtures.tree200
        #expect(tree.update("card-3") { $0.name = "Promo" })
        #expect(tree.node("card-3")?.name == "Promo")
        #expect(!tree.update("nowhere") { $0.name = "Lost" })
        #expect(tree.node("nowhere") == nil)
    }

    @Test(.disabled("waits on EK-12")) func movesIntoParentAtIndex() {
        var tree = KernelFixtures.tree200
        #expect(refusal { try tree.move("card-7", into: "header", at: 3) } == nil)
        #expect(tree.node("header")?.children.map(\.id) == ["header-1", "header-2", "header-3", "card-7"])
        #expect(tree.node("cards")?.children.count == 29)
        #expect(tree.ancestors(of: "card-7") == ["header"])
        // An index past the end clamps to the count; nil moves to the roots.
        #expect(refusal { try tree.move("hero-1", into: "header", at: 99) } == nil)
        #expect(tree.node("header")?.children.last?.id == "hero-1")
        #expect(refusal { try tree.move("card-8", into: nil, at: 0) } == nil)
        #expect(tree.roots.first?.id == "card-8")
        #expect(tree.frontToBack.count == 200)
    }

    @Test(.disabled("waits on EK-12")) func moveRefusals() {
        var tree = KernelFixtures.tree200
        #expect(refusal { try tree.move("nowhere", into: "header", at: 0) } == .unknown("nowhere"))
        #expect(refusal { try tree.move("card-1", into: "nowhere", at: 0) } == .unknown("nowhere"))
        #expect(refusal { try tree.move("gallery", into: "gallery", at: 0) } == .intoItself("gallery"))
        #expect(refusal { try tree.move("card-1", into: "card-2", at: 0) } == .notAContainer("card-2"))
        #expect(refusal { try tree.move("card-1", into: "footer", at: 0) } == .locked("footer"))
        #expect(tree == KernelFixtures.tree200)
    }

    @Test(.disabled("waits on EK-12")) func refusesIntoOwnDescendant() {
        var tree = KernelFixtures.tree200
        // Two levels down, not only a direct child.
        #expect(refusal { try tree.move("gallery", into: "row-2-col-3", at: 0) } == .intoItself("row-2-col-3"))
        #expect(refusal { try tree.move("gallery", into: "row-2", at: 0) } == .intoItself("row-2"))
        #expect(tree == KernelFixtures.tree200)
    }

    @Test(.disabled("waits on EK-12")) func arrangesAmongSiblings() {
        var tree = Self.flat
        #expect(refusal { try tree.arrange(.bringToFront, ["a"]) } == nil)
        #expect(Self.rootIDs(tree) == ["b", "c", "d", "a"])
        tree = Self.flat
        #expect(refusal { try tree.arrange(.bringForward, ["b"]) } == nil)
        #expect(Self.rootIDs(tree) == ["a", "c", "b", "d"])
        tree = Self.flat
        #expect(refusal { try tree.arrange(.sendBackward, ["c"]) } == nil)
        #expect(Self.rootIDs(tree) == ["a", "c", "b", "d"])
        tree = Self.flat
        #expect(refusal { try tree.arrange(.sendToBack, ["d"]) } == nil)
        #expect(Self.rootIDs(tree) == ["d", "a", "b", "c"])
        // Several ids keep their order among themselves.
        tree = Self.flat
        #expect(refusal { try tree.arrange(.bringToFront, ["a", "c"]) } == nil)
        #expect(Self.rootIDs(tree) == ["b", "d", "a", "c"])
        #expect(refusal { try tree.arrange(.bringForward, ["nowhere"]) } == .unknown("nowhere"))
    }

    @Test(.disabled("waits on EK-12")) func bringForwardAtTopStays() {
        var tree = Self.flat
        #expect(refusal { try tree.arrange(.bringForward, ["d"]) } == nil)
        #expect(tree == Self.flat)
        #expect(refusal { try tree.arrange(.sendBackward, ["a"]) } == nil)
        #expect(tree == Self.flat)
    }

    @Test(.disabled("waits on EK-12")) func groupsUnderANewNode() throws {
        var tree = Self.flat
        let id = try tree.group(["b", "c"], name: "Pair", payload: TreeItem(holdsChildren: true)) { "pair" }
        #expect(id == "pair")
        #expect(Self.rootIDs(tree) == ["a", "pair", "d"])
        #expect(tree.node("pair")?.name == "Pair")
        #expect(tree.node("pair")?.children.map(\.id) == ["b", "c"])
        var other = Self.flat
        let unknown = refusal {
            _ = try other.group(["b", "nowhere"], name: "G", payload: TreeItem(holdsChildren: true)) { "g" }
        }
        #expect(unknown == .unknown("nowhere"))
        #expect(other == Self.flat)
    }

    @Test(.disabled("waits on EK-12")) func ungroupKeepsOrder() {
        var tree = LayerTree([leaf("a"), group("g", [leaf("x"), leaf("y"), leaf("z")]), leaf("d")])
        #expect(refusal { try tree.ungroup("g") } == nil)
        #expect(Self.rootIDs(tree) == ["a", "x", "y", "z", "d"])
        #expect(tree.node("g") == nil)
        #expect(refusal { try tree.ungroup("x") } == .notAContainer("x"))
        #expect(refusal { try tree.ungroup("nowhere") } == .unknown("nowhere"))
    }

    @Test(.disabled("waits on EK-12")) func duplicatesInFrontWithFreshIDs() {
        var tree = LayerTree([leaf("a"), group("g", [leaf("x")]), leaf("c")])
        var mint = Mint()
        let copies = tree.duplicate(["a"]) { mint.next() }
        #expect(copies == ["m1"])
        #expect(Self.rootIDs(tree) == ["a", "m1", "g", "c"])
        #expect(tree.node("m1")?.name == "A")
        // A group's copy mints a fresh id for every descendant too.
        let groupCopies = tree.duplicate(["g"]) { mint.next() }
        #expect(groupCopies.count == 1)
        #expect(tree.roots.count == 5)
        #expect(Set(tree.frontToBack).count == tree.frontToBack.count)
        #expect(tree.frontToBack.count == 7)
        let before = tree
        #expect(tree.duplicate(["nowhere"]) { mint.next() } == [])
        #expect(tree == before)
    }
}
