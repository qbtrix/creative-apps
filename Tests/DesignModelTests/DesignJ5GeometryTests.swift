// DesignJ5GeometryTests.swift: the page points journey J5 (DesignSelectJourneyTests,
// select-several SS-a) presses, played on `cards` with the live services. After the
// marquee picks A (100, 100, 100, 80) and B (300, 140, 200, 80) and A's middle drags
// 40 right, the box is (140, 100)-(540, 220): its bottom-right handle sits at
// (540, 220), and (500, 220) is B's bottom edge, a Move (#2517). The tolerance is the
// window's grab area at about the fitted zoom of a 1024 × 768 window. Runs on Linux
// and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignJ5GeometryTests {
    /// `cards` on the live services after J5's marquee and move, at a 16 pt grab area.
    static func moved() -> DesignWorkspace {
        var workspace = DesignFixtures.cards
        workspace.useServices(.live)
        workspace.setHandleTolerance(16)
        workspace.gesture(.move, pt(80, 80), pt(520, 240))
        workspace.gesture(.move, pt(150, 140), pt(190, 140))
        return workspace
    }

    @Test func theMarqueeAndMoveLeaveTheBoxAt140To540() {
        let workspace = Self.moved()
        #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
        #expect(workspace.undoActionName == "Undo Move")
        #expect(workspace.selectionBounds == rc(140, 100, 400, 120))
    }

    @Test func theBoxsBottomRightHandleResizesBothAsOneStep() {
        var workspace = Self.moved()
        #expect(workspace.boxHandle(at: pt(540, 220)) == .bottomRight)
        workspace.gesture(.move, pt(540, 220), pt(560, 220))
        #expect(workspace.undoActionName == "Undo Resize")
        #expect(workspace.selectionBounds == rc(140, 100, 420, 120))
    }

    @Test func aPressOnBsBottomEdgeIsAMoveNotAResize() {
        var workspace = Self.moved()
        #expect(workspace.boxHandle(at: pt(500, 220)) == nil)
        workspace.gesture(.move, pt(500, 220), pt(520, 220))
        #expect(workspace.undoActionName == "Undo Move")
    }
}
