// DesignReparentRebaseTests.swift: a keyed layer that changes parent keeps where it shows at the playhead
// (one-document OD-7, rule 3 of 4). Group, Ungroup and the Layers panel's Move Layer shift a moved keyed layer's
// x and y keys by its old containers' shown offset minus its new ones', so the jump a parent's animation would add
// cancels at the playhead. On `animated(50)` node-2 rests at 30, 30 and shows 47, 40 at frame 60, 5 of that x from
// its frame node-1 (keys x 10 to 20). A layer with no keys is not rebased (it still jumps: the known ceiling).
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignReparentRebaseTests {
    /// `animated(50)` with `ids` selected and the playhead at `frame`.
    static func at(_ frame: Int?, _ ids: String...) -> DesignWorkspace {
        var workspace = DesignFixtures.animated(50)
        workspace.useServices(.live)
        workspace.playhead = frame
        for id in ids { workspace.selectItem(id) }
        return workspace
    }

    /// Node `id` as `workspace` shows it at `frame`.
    static func shown(_ workspace: DesignWorkspace, _ id: String, at frame: Double) -> DesignPoint {
        let node = workspace.selectedPage!.sampled(at: frame).nodes.node(id)!
        return DesignPoint(x: node.frame.x, y: node.frame.y)
    }

    static func near(_ a: DesignPoint, _ x: Double, _ y: Double) -> Bool { abs(a.x - x) < 0.01 && abs(a.y - y) < 0.01 }

    static func xKeys(_ workspace: DesignWorkspace, _ id: String) -> [Double] {
        workspace.selectedPage!.nodes.node(id)!.time!.tracks[.x]!.map(\.value)
    }

    @Test func groupingInsideTheAnimatedFrameMovesNothingAndTheGroupStaysStill() throws {
        var workspace = Self.at(60, "node-2", "node-3")
        let before = (Self.shown(workspace, "node-3", at: 60), Self.shown(workspace, "node-3", at: 0))
        try workspace.run(.group)
        let group = try #require(workspace.selectedPage!.nodes.node(workspace.selectedNodeIDs.last!))
        #expect(group.kind == .group && group.time == nil)
        #expect(Self.near(Self.shown(workspace, "node-2", at: 60), 47, 40))
        #expect(Self.near(Self.shown(workspace, "node-2", at: 0), 30, 30))
        #expect(Self.shown(workspace, "node-3", at: 60) == before.0 && Self.shown(workspace, "node-3", at: 0) == before.1)
        try workspace.run(.ungroup)
        #expect(Self.near(Self.shown(workspace, "node-2", at: 60), 47, 40))
        #expect(Self.near(Self.shown(workspace, "node-2", at: 0), 30, 30))
    }

    @Test func ungroupingAnAnimatedGroupKeepsItsChildrenWhereTheyShow() throws {
        var workspace = Self.at(60, "node-1")
        workspace.pages[0].nodes[0].kind = .group
        let keys = Self.xKeys(workspace, "node-2")
        try workspace.run(.ungroup)
        #expect(workspace.selectedPage!.nodes.node("node-2") != nil)
        #expect(Self.near(Self.shown(workspace, "node-2", at: 60), 47, 40))
        #expect(Self.xKeys(workspace, "node-2") == keys.map { $0 + 5 })
    }

    @Test func movingOutOfTheAnimatedFrameRebasesByItsOffsetAndBackInUndoesIt() throws {
        var workspace = Self.at(60)
        let keys = Self.xKeys(workspace, "node-2")
        try workspace.moveLayer("node-2", into: nil, at: 0)
        #expect(workspace.selectedPage!.nodes.contains { $0.id == "node-2" })
        #expect(Self.near(Self.shown(workspace, "node-2", at: 60), 47, 40))
        #expect(Self.xKeys(workspace, "node-2") == keys.map { $0 + 5 })
        try workspace.moveLayer("node-2", into: "node-1", at: 0)
        #expect(Self.near(Self.shown(workspace, "node-2", at: 60), 47, 40))
        #expect(Self.xKeys(workspace, "node-2") == keys)
        workspace.undo()
        #expect(Self.xKeys(workspace, "node-2") == keys.map { $0 + 5 })
    }

    @Test func noPlayheadOrNoKeysRebasesNothing() throws {
        var rest = Self.at(nil)
        let keys = Self.xKeys(rest, "node-2")
        try rest.moveLayer("node-2", into: nil, at: 0)
        #expect(Self.xKeys(rest, "node-2") == keys)
        // A still layer leaving the animated frame keeps its rest frame, so it jumps by the frame's offset.
        var still = Self.at(60)
        still.pages[0].nodes[0].children[0].time = nil
        try still.moveLayer("node-2", into: nil, at: 0)
        #expect(still.selectedPage!.nodes.node("node-2")!.frame == DesignRect(x: 30, y: 30, width: 24, height: 16))
    }
}
