// LayerFollowTests.swift (editor-kernel EK-11, slice EK-tree, KJ3): the
// follow link, written before its body. A layer follows another directly or
// through others; its world placement composes the followed layer's first;
// `setFollow` refuses a cycle (however deep) and an unknown id, and keeps the
// layer where it is on screen by handing `keepingPlace` the new local
// placement. EK-13 wrote `LayerFollow` and turned them on. `found` walks the
// roots itself, so these checks hold whether or not `node(_:)` (EK-12) has
// its body.
import Testing
import SuiteKernel

/// A payload that carries its own local placement.
private struct Placed: LayerPayload {
    var holdsChildren = false
    var local: Matrix
}

@Suite struct LayerFollowTests {
    private static func placed(_ id: String, _ local: Matrix, follows: String? = nil) -> LayerNode<Placed> {
        LayerNode(id: id, name: id, followsID: follows, payload: Placed(local: local))
    }

    private static func local(_ node: LayerNode<Placed>) -> Matrix { node.payload.local }

    /// The node with `id` anywhere in `tree`, read straight from the roots.
    private static func found(_ tree: LayerTree<Placed>, _ id: String) -> LayerNode<Placed>? {
        var stack = tree.roots
        while let node = stack.popLast() {
            if node.id == id { return node }
            stack.append(contentsOf: node.children)
        }
        return nil
    }

    private static func keep(_ node: inout LayerNode<Placed>, _ local: Matrix) { node.payload.local = local }

    /// a at x 100; b follows a, scaled by 2; c follows b, at x 5; d follows nothing at x 30.
    private static let chain = LayerTree([
        placed("a", .translation(x: 100, y: 0)),
        placed("b", .scale(x: 2, y: 2), follows: "a"),
        placed("c", .translation(x: 5, y: 0), follows: "b"),
        placed("d", .translation(x: 30, y: 0)),
    ])

    /// The tree's refusal for `setFollow(id, parent)`, nil when it takes it.
    private static func follow(_ tree: inout LayerTree<Placed>, _ id: String, _ parent: String?) -> TreeRefusal? {
        do throws(TreeRefusal) {
            try tree.setFollow(id, parent, local: local, keepingPlace: keep)
            return nil
        } catch {
            return error
        }
    }

    @Test func followsDirectlyAndThrough() {
        let tree = Self.chain
        #expect(tree.follows("b", "a"))
        #expect(tree.follows("c", "b"))
        #expect(tree.follows("c", "a"))
        #expect(!tree.follows("a", "c"))
        #expect(!tree.follows("d", "a"))
        #expect(!tree.follows("nowhere", "a"))
    }

    @Test func worldComposesParentFirst() {
        let tree = Self.chain
        // b scales first, then a moves it: (1, 0) -> (2, 0) -> (102, 0), not (202, 0).
        #expect(tree.worldPlacement(of: "b", local: Self.local).apply(Point(x: 1, y: 0)) == Point(x: 102, y: 0))
        // c: (0, 0) -> (5, 0) -> (10, 0) -> (110, 0).
        #expect(tree.worldPlacement(of: "c", local: Self.local).apply(Point(x: 0, y: 0)) == Point(x: 110, y: 0))
        #expect(tree.worldPlacement(of: "d", local: Self.local) == .translation(x: 30, y: 0))
    }

    @Test func refusesCycle() {
        var tree = Self.chain
        #expect(Self.follow(&tree, "a", "a") == .cycle("a"))
        #expect(Self.follow(&tree, "a", "b") == .cycle("a"))
        #expect(tree == Self.chain)
    }

    @Test func refusesCycleTwoDeep() {
        var tree = Self.chain
        // c follows b follows a, so a may not follow c.
        #expect(Self.follow(&tree, "a", "c") == .cycle("a"))
        #expect(tree == Self.chain)
    }

    @Test func refusesUnknown() {
        var tree = Self.chain
        #expect(Self.follow(&tree, "nowhere", "a") == .unknown("nowhere"))
        #expect(Self.follow(&tree, "d", "nowhere") == .unknown("nowhere"))
        #expect(tree == Self.chain)
    }

    @Test func keepsScreenPlace() {
        var tree = Self.chain
        let before = tree.worldPlacement(of: "d", local: Self.local)
        #expect(Self.follow(&tree, "d", "a") == nil)
        #expect(Self.found(tree, "d")?.followsID == "a")
        #expect(Self.found(tree, "d")?.payload.local == .translation(x: -70, y: 0))
        #expect(tree.worldPlacement(of: "d", local: Self.local) == before)
        #expect(tree.follows("d", "a"))
    }

    @Test func unfollowKeepsScreenPlace() {
        var tree = Self.chain
        let before = tree.worldPlacement(of: "c", local: Self.local)
        #expect(Self.follow(&tree, "c", nil) == nil)
        #expect(Self.found(tree, "c")?.followsID == nil)
        #expect(Self.found(tree, "c")?.payload.local == before)
        #expect(tree.worldPlacement(of: "c", local: Self.local) == before)
        #expect(!tree.follows("c", "a"))
    }

    @Test func followsAcrossNesting() {
        // e sits inside g and follows a, a root: the link ignores nesting.
        var tree = LayerTree([
            Self.placed("a", .translation(x: 100, y: 0)),
            LayerNode(id: "g", name: "g", children: [Self.placed("e", .translation(x: 1, y: 0))],
                      payload: Placed(holdsChildren: true, local: .identity)),
        ])
        #expect(Self.follow(&tree, "e", "a") == nil)
        #expect(tree.follows("e", "a"))
        #expect(Self.found(tree, "e")?.payload.local == .translation(x: -99, y: 0))
        #expect(tree.worldPlacement(of: "e", local: Self.local) == .translation(x: 1, y: 0))
        #expect(Self.follow(&tree, "a", "e") == .cycle("a"))
    }
}
