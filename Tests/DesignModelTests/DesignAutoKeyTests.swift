// DesignAutoKeyTests.swift: auto-key at the playhead (one-document OD-5, rule 1 of 4). At a playhead, an edit to
// a property a node already keys writes a key there with the asked-for value, so the canvas shows what was asked
// and the rest pose (and every other frame's keys) stays; a property with no track, or no playhead, edits the rest
// pose as before. Covers move, nudge, align, the X/Y rows and opacity, on the live services and on the one-layer
// workspace paths. On `animated(50)` at frame 60 node-2 shows x 47, y 40, opacity 0.65; its rest frame is 30, 30.
// Runs on Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignAutoKeyTests {
    static let page = DesignFixtures.animated(50).selectedPage!
    static let rest = page.nodes.node("node-2")!

    /// Node `id` of `nodes` as it shows at `frame`.
    static func shown(_ nodes: [DesignNode], _ id: String, at frame: Double) -> DesignNode {
        var page = Self.page
        page.nodes = nodes
        return page.sampled(at: frame).nodes.node(id)!
    }

    static func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

    /// The rest pose of `id` (frame and opacity) is the same in `nodes` as in the fixture.
    static func restKept(_ nodes: [DesignNode], _ id: String) -> Bool {
        let (old, new) = (page.nodes.node(id)!, nodes.node(id)!)
        return old.frame == new.frame && old.opacity == new.opacity
    }

    @Test func moveKeysTheShownPositionAtThePlayhead() throws {
        let edit = try LiveTransforming().move(["node-2"], by: DesignPoint(x: 100, y: 0), on: Self.page, at: 60)
        #expect(Self.near(Self.shown(edit.nodes, "node-2", at: 60).frame.x, 147))
        #expect(Self.near(Self.shown(edit.nodes, "node-2", at: 60).frame.y, 40))
        #expect(Self.near(Self.shown(edit.nodes, "node-2", at: 0).frame.x, 30))
        #expect(Self.restKept(edit.nodes, "node-2"))
        #expect(edit.nodes.node("node-2")?.time?.tracks[.x]?.map(\.frame) == [0, 60, 120])
    }

    @Test func nudgeKeysAtThePlayhead() throws {
        let edit = try LiveTransforming().nudge(["node-2", "node-3"], .right, large: true, on: Self.page, at: 60)
        #expect(Self.near(Self.shown(edit.nodes, "node-2", at: 60).frame.x, 57))
        #expect(Self.restKept(edit.nodes, "node-2"))
    }

    @Test func aKeyAlreadyAtThePlayheadIsReplaced() throws {
        let once = try LiveTransforming().move(["node-2"], by: DesignPoint(x: 100, y: 0), on: Self.page, at: 120)
        var page = Self.page
        page.nodes = once.nodes
        let twice = try LiveTransforming().move(["node-2"], by: DesignPoint(x: 10, y: 0), on: page, at: 120)
        #expect(twice.nodes.node("node-2")?.time?.tracks[.x]?.map(\.value) == [30, 164])
    }

    @Test func theXRowAndOpacityKeyAtThePlayhead() throws {
        let x = try LiveStyling().setFrame(.x, to: 500, ["node-2", "node-3"], on: Self.page, at: 60)
        #expect(Self.near(Self.shown(x.nodes, "node-2", at: 60).frame.x, 500))
        #expect(Self.near(Self.shown(x.nodes, "node-2", at: 60).frame.y, 40))
        #expect(Self.restKept(x.nodes, "node-2"))
        let opacity = try LiveStyling().setOpacity(0.9, ["node-2", "node-3"], on: Self.page, at: 60)
        #expect(Self.near(Self.shown(opacity.nodes, "node-2", at: 60).opacity, 0.9))
        #expect(Self.near(Self.shown(opacity.nodes, "node-2", at: 0).opacity, 1))
        #expect(Self.restKept(opacity.nodes, "node-2"))
    }

    @Test func alignLinesUpTheShownFramesAndLeavesFrameZero() throws {
        let edit = try LiveAligning().align(.left, ["node-2", "node-30"], on: Self.page, at: 60)
        #expect(Self.near(Self.shown(edit.nodes, "node-2", at: 60).frame.x, 47))
        #expect(Self.near(Self.shown(edit.nodes, "node-30", at: 60).frame.x, 47))
        let before = Self.page.sampled(at: 0).nodes.node("node-30")!.frame
        #expect(Self.shown(edit.nodes, "node-30", at: 0).frame == before)
        #expect(Self.restKept(edit.nodes, "node-30"))
    }

    @Test func anUnkeyedAxisOrNoPlayheadEditsTheRestPose() throws {
        // node-1 keys x only: a y move at 60 moves its rest pose, children with it.
        let y = try LiveTransforming().move(["node-1"], by: DesignPoint(x: 0, y: 5), on: Self.page, at: 60)
        #expect(y.nodes.node("node-1")?.frame.y == 15)
        #expect(y.nodes.node("node-1")?.time == Self.page.nodes.node("node-1")?.time)
        let still = try LiveTransforming().move(["node-2"], by: DesignPoint(x: 100, y: 0), on: Self.page)
        #expect(still.nodes.node("node-2")?.frame.x == 130)
        #expect(still.nodes.node("node-2")?.time == Self.rest.time)
    }

    // MARK: - The workspace's one-layer paths and the drag

    static func at(_ frame: Int?, selecting ids: [String]) -> DesignWorkspace {
        var workspace = DesignFixtures.animated(50)
        workspace.useServices(.live)
        workspace.playhead = frame
        workspace.selectItem(ids[0])
        for id in ids.dropFirst() { workspace.toggleSelection(id) }
        return workspace
    }

    static func shown(_ workspace: DesignWorkspace, _ id: String) -> DesignNode { workspace.shownPage!.nodes.node(id)! }

    @Test func oneLayerNudgeKeysAndUndoRemovesTheKey() {
        var workspace = Self.at(60, selecting: ["node-2"])
        workspace.nudge(.right, shift: true)
        #expect(Self.near(Self.shown(workspace, "node-2").frame.x, 57))
        #expect(Self.restKept(workspace.selectedPage!.nodes, "node-2"))
        workspace.undo()
        #expect(workspace.selectedPage == Self.page)
    }

    @Test func oneLayerAlignAndRowsShowWhatWasAsked() throws {
        var workspace = Self.at(60, selecting: ["node-2"])
        #expect(workspace.alignHelp(.left) == nil)
        workspace.alignLayer(.left)  // the frame shows at x 15 at 60
        #expect(Self.near(Self.shown(workspace, "node-2").frame.x, 15))
        try workspace.setStyle(.frame(.x, 200))
        #expect(Self.near(Self.shown(workspace, "node-2").frame.x, 200))
        #expect(Self.near(Self.shown(workspace, "node-2").frame.y, 40))
        try workspace.setStyle(.opacity(0.9))
        #expect(Self.near(Self.shown(workspace, "node-2").opacity, 0.9))
        #expect(Self.restKept(workspace.selectedPage!.nodes, "node-2"))
    }

    @Test func dragsMoveTheShownLayers() {
        for ids in [["node-2"], ["node-2", "node-3"]] {
            var workspace = Self.at(60, selecting: ids)
            let start = Self.shown(workspace, "node-2").frame
            let from = DesignPoint(x: start.x + 4, y: start.y + 4)
            workspace.drag(from: from, to: DesignPoint(x: from.x + 200, y: from.y + 150))
            workspace.endDrag()
            #expect(Self.shown(workspace, "node-2").frame.x > start.x + 150, "\(ids)")
            #expect(Self.restKept(workspace.selectedPage!.nodes, "node-2"), "\(ids)")
        }
    }
}
