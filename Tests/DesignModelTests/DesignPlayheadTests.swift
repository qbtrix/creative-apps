// DesignPlayheadTests.swift: the playhead (one-document OD-4). With `DesignWorkspace.playhead` set, every read the
// canvas makes of the page (hit-test, the handle under the pointer, snap candidates, the marquee, Zoom to Selection)
// sees the tree sampled at that frame (`shownPage`); with it nil each read is the rest pose, as before. The
// playhead is shown state: setting it is no edit, no undo step, no unsaved change. On `animated(50)` at frame 60
// node-2 shows at about x 47, y 40 (its rest frame is 30, 30, 24, 16). A move snaps the box the canvas shows, and
// a load or New File puts the playhead back to the rest pose. Runs on Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignPlayheadTests {
    /// `animated(50)` on the live services with the playhead at `frame`.
    static func at(_ frame: Int?, selecting ids: [String] = []) -> DesignWorkspace {
        var workspace = DesignFixtures.animated(50)
        workspace.useServices(.live)
        workspace.playhead = frame
        for id in ids { workspace.selectItem(id) }
        return workspace
    }

    static let rest = at(nil).selectedPage!.nodes.node("node-2")!.frame
    static let shown = at(60).selectedPage!.sampled(at: 60).nodes.node("node-2")!.frame

    @Test func shownPageIsTheSampledPageOnlyWithAPlayhead() {
        #expect(abs(Self.shown.x - 47) < 1 && abs(Self.shown.y - 40) < 1)
        #expect(Self.at(60).shownPage == Self.at(60).selectedPage!.sampled(at: 60))
        #expect(Self.at(nil).shownPage == Self.at(nil).selectedPage)
    }

    @Test func movingThePlayheadIsNoEdit() {
        var workspace = Self.at(nil)
        let pages = workspace.pages
        workspace.playhead = 60
        #expect(workspace.pages == pages && !workspace.canUndo && !workspace.isDirty)
    }

    @Test func hitTestFindsTheSampledNode() {
        // Inside node-2 as it shows at 60 and right of it at rest; and inside it at rest only.
        #expect(Self.at(60).hitTest(pt(65, 52)) == "node-2")
        #expect(Self.at(nil).hitTest(pt(65, 52)) != "node-2")
        #expect(Self.at(nil).hitTest(pt(32, 32)) == "node-2")
        #expect(Self.at(60).hitTest(pt(32, 32)) != "node-2")
    }

    @Test func theHandleUnderTheSampledCornerIsFound() {
        let workspace = Self.at(60, selecting: ["node-2"])
        let corner = Self.shown.handles(size: workspace.handleTolerance)[.bottomRight]!
        #expect(workspace.handle(at: corner) == .bottomRight)
        #expect(Self.at(nil, selecting: ["node-2"]).handle(at: corner) == nil)
    }

    @Test func snapCandidatesAreTheSampledFrames() {
        func frame(_ workspace: DesignWorkspace) -> DesignSnapCandidate? {
            workspace.snapCandidates(moving: ["node-3"], drawingInto: nil).first { $0.id == "node-2" }
        }
        #expect(frame(Self.at(60))?.frame == Self.shown.snapRect)
        #expect(frame(Self.at(nil))?.frame == Self.rest.snapRect)
    }

    @Test func aMarqueeOverTheSampledRectanglePicksIt() {
        // From the frame's empty area (right of node-2 at 60) over node-2's sampled box, clear of its rest box.
        var keyed = Self.at(60)
        keyed.gesture(.move, pt(75, 58), pt(60, 50))
        #expect(keyed.selectedNodeIDs == ["node-2"])
        var still = Self.at(nil)
        still.gesture(.move, pt(75, 58), pt(60, 50))
        #expect(still.selectedNodeIDs == [])
    }

    @Test func zoomToSelectionShowsTheSampledBounds() {
        #expect(Self.at(60, selecting: ["node-2"]).zoomToSelectionRect == Self.shown)
        #expect(Self.at(nil, selecting: ["node-2"]).zoomToSelectionRect == Self.rest)
    }

    /// node-2 as it shows at 60 after `workspace`'s gesture.
    static func shownAt60(_ workspace: DesignWorkspace) -> DesignRect? { workspace.sampledNode("node-2", at: 60)?.frame }

    @Test func aOneLayerMoveSnapsTheShownBox() {
        // Shown at 47..71, +28 puts its right edge 2 from node-3's shown left (101): it snaps to 30. The rest box
        // (30..54) would snap +1 in x and +2 in y to the shown lines instead.
        var workspace = Self.at(60)
        workspace.gesture(.move, pt(59, 48), pt(87, 48))
        #expect(Self.shownAt60(workspace).map { [$0.x, $0.y] } == [77, 40])
    }

    @Test func aSeveralLayerMoveSnapsTheShownBox() {
        // node-2 and node-3 shown span 47..125 by 40..56; +28 lands its centre 1 past node-28's (113): it snaps to 27.
        var workspace = Self.at(60, selecting: ["node-2"])
        workspace.toggleSelection("node-3")
        workspace.gesture(.move, pt(59, 48), pt(87, 48))
        #expect(Self.shownAt60(workspace).map { [$0.x, $0.y] } == [74, 40])
    }

    @Test func loadAndNewFileShowTheRestPose() throws {
        var opened = Self.at(60)
        opened.time.durationFrames = 600
        let bytes = try opened.fileData()
        opened.load(opened.pages)
        #expect(opened.playhead == nil)
        var fresh = Self.at(60)
        fresh.time.durationFrames = 600
        fresh.newFile()
        #expect(fresh.playhead == nil && fresh.time == DesignDocumentTime())
        fresh.undo()
        #expect(try fresh.fileData() == bytes, "undoing New File brings back the file's rate and length")
    }
}
