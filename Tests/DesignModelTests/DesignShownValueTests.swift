// DesignShownValueTests.swift: at a playhead the inspector's X, Y and Opacity read the layer as the canvas shows it
// (DesignWorkspace.shown, through liveFrame), not its rest pose (one-document OD-15). With no playhead they read the
// rest pose, as before. Linux-safe.
@testable import DesignModel
import Testing

@Suite struct DesignShownValueTests {
    @Test func aPlayheadShowsTheSampledFrameAndOpacity() throws {
        var w = DesignFixtures.animated(1)
        let frame = try #require(w.findNode("node-1")), cell = try #require(w.findNode("node-2"))
        #expect(w.liveFrame(of: frame, draft: nil) == frame.frame && w.shown(cell).opacity == cell.opacity)
        w.setPlayhead(60)
        let onScreen = try #require(w.shownPage?.nodes.node("node-1"))
        let shownCell = try #require(w.shownPage?.nodes.node("node-2"))
        #expect(onScreen.frame.x != frame.frame.x, "the fixture's frame doesn't move by 60")
        #expect(w.liveFrame(of: frame, draft: nil) == onScreen.frame)
        #expect(w.shown(cell).opacity == shownCell.opacity && shownCell.opacity != cell.opacity)
    }

    @Test func noPlayheadReadsTheRestPose() throws {
        var w = DesignFixtures.animated(1)
        w.setPlayhead(60)
        w.setPlayhead(nil)
        let cell = try #require(w.findNode("node-2"))
        #expect(w.shown(cell) == cell)
    }
}
