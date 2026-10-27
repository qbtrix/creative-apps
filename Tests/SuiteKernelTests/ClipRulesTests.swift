// ClipRulesTests.swift (layer-styles LS-10, slice LS-clip, KJ-clip): the
// clipping rule on the kernel's layer tree. A clipped layer's base is the
// nearest unclipped layer below it among its siblings; the bottom layer has
// none; the walk never leaves its sibling list, so a clip stays inside its
// group; and a base's clipped layers are the run of clipped layers right
// above it.
import Testing
import SuiteKernel

/// A payload that says whether its layer is clipped to the layer below.
private struct Clip: LayerPayload {
    var holdsChildren = false
    var isClipped = false
}

/// A layer named `id`; a group when it has children.
private func layer(_ id: String, clipped: Bool = false, children: [LayerNode<Clip>] = []) -> LayerNode<Clip> {
    LayerNode(id: id, name: id, children: children,
              payload: Clip(holdsChildren: !children.isEmpty, isClipped: clipped))
}

@Suite struct ClipRulesTests {
    private static func base(_ id: String, _ siblings: [LayerNode<Clip>]) -> String? {
        ClipRules.base(of: id, in: siblings) { $0.isClipped }
    }

    private static func clipped(_ id: String, _ siblings: [LayerNode<Clip>]) -> [String] {
        ClipRules.clipped(onto: id, in: siblings) { $0.isClipped }
    }

    /// [A, B(clipped), C(clipped)], back to front.
    private static let stack = [layer("A"), layer("B", clipped: true), layer("C", clipped: true)]

    @Test func aClippedLayerClipsToTheNearestUnclippedLayerBelow() {
        #expect(Self.base("C", Self.stack) == "A")
        #expect(Self.base("B", Self.stack) == "A")
    }

    @Test func theBottomLayerHasNoBase() {
        #expect(Self.base("A", Self.stack) == nil)
        #expect(Self.base("X", [layer("X", clipped: true), layer("Y")]) == nil)
    }

    @Test func onlyClippedLayersBelowGiveNoBase() {
        let siblings = [layer("X", clipped: true), layer("Y", clipped: true)]
        #expect(Self.base("Y", siblings) == nil)
    }

    @Test func theWalkStopsAtTheFirstUnclippedLayer() {
        let siblings = [layer("A"), layer("D"), layer("C", clipped: true)]
        #expect(Self.base("C", siblings) == "D")
        #expect(Self.base("D", siblings) == "A")
    }

    @Test func aGroupBoundaryStopsTheWalk() {
        let group = layer("G", children: [layer("X", clipped: true), layer("Y", clipped: true)])
        let tree = LayerTree([layer("A"), group, layer("C", clipped: true)])
        let inside = tree.node("G")?.children ?? []
        #expect(inside.count == 2)
        #expect(Self.base("X", inside) == nil)
        #expect(Self.base("Y", inside) == nil)
        #expect(Self.base("C", tree.roots) == "G")
    }

    @Test func aClippedLayerAboveAGroupHasThatGroupAsItsBase() {
        let group = layer("G", children: [layer("X")])
        #expect(Self.base("C", [layer("A"), group, layer("C", clipped: true)]) == "G")
        #expect(Self.clipped("G", [layer("A"), group, layer("C", clipped: true)]) == ["C"])
        #expect(ClipRules.notClippedHelp == "This layer isn't clipped.")
    }

    @Test func anUnknownIdHasNoBase() {
        #expect(Self.base("Z", Self.stack) == nil)
        #expect(Self.clipped("Z", Self.stack).isEmpty)
    }

    @Test func aBaseClipsTheRunOfClippedLayersAboveIt() {
        #expect(Self.clipped("A", Self.stack) == ["B", "C"])
        let siblings = Self.stack + [layer("D"), layer("E", clipped: true)]
        #expect(Self.clipped("A", siblings) == ["B", "C"])
        #expect(Self.clipped("D", siblings) == ["E"])
        #expect(Self.clipped("E", siblings).isEmpty)
    }

    @Test func aClippedLayerIsNoBase() {
        #expect(Self.clipped("B", Self.stack).isEmpty)
    }
}
