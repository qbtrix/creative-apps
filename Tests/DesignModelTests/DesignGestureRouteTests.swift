// DesignGestureRouteTests.swift: the Move tool's gesture routes on `cards` with the
// fake services (design-seams D0-3c). A press on an unselected frame's background,
// or outside every layer, is a marquee at that level that records nothing; with
// several layers selected a drag moves or resizes them all as one step; every
// step rewinds to the gesture's start, so the last sample alone gives the same
// workspace; endDrag clears the marquee. MJ5 walks them in a row. Runs on Linux
// and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignGestureRouteTests {
    /// `cards` on the fake services: Desktop node-1 holds A node-2, B node-3, C node-4, Title
    /// node-5, Pair node-6, Locked node-9 and Hidden node-10.
    static func cards() -> DesignWorkspace {
        var workspace = DesignFixtures.cards
        workspace.useServices(.fake)
        return workspace
    }

    /// `cards` with A and B selected.
    static func aAndB() -> DesignWorkspace {
        var workspace = cards()
        workspace.selectItem("node-2")
        workspace.toggleSelection("node-3")
        return workspace
    }

    @Test func aPressOnDesktopsBackgroundMarqueesItsChildrenAndRecordsNothing() {
        var workspace = Self.cards()
        workspace.drag(from: pt(80, 80), to: pt(520, 240))
        #expect(workspace.marquee == rc(80, 80, 440, 160))
        #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
        workspace.endDrag()
        #expect(workspace.marquee == nil)
        #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
        #expect(workspace.history.undo.isEmpty)
        #expect(workspace.pages == Self.cards().pages)
    }

    @Test func withDesktopSelectedTheSamePressMovesIt() {
        var workspace = Self.cards()
        workspace.selectItem("node-1")
        workspace.gesture(.move, pt(80, 80), pt(120, 80))
        #expect(workspace.frame("node-1") == rc(40, 0, 1440, 1024))
        #expect(workspace.undoActionName == "Undo Move")
        #expect(workspace.marquee == nil)
    }

    @Test func aClickOnDesktopsBackgroundSelectsIt() {
        var workspace = Self.cards()
        workspace.selectItem("node-4")
        workspace.drag(from: pt(80, 80), to: pt(80, 80))
        #expect(workspace.marquee == nil)
        workspace.endDrag()
        #expect(workspace.selectedNodeIDs == ["node-1"])
        #expect(workspace.history.undo.isEmpty)
    }

    @Test func aPressOutsideThePageMarqueesTheTopLevel() {
        var workspace = Self.cards()
        workspace.selectItem("node-2")
        workspace.drag(from: pt(1500, 1100), to: pt(1400, 1000))
        #expect(workspace.marquee == rc(1400, 1000, 100, 100))
        #expect(workspace.selectedNodeIDs == ["node-1"])
        workspace.endDrag()
        #expect(workspace.selectedNodeIDs == ["node-1"])
        #expect(workspace.marquee == nil)
        #expect(workspace.history.undo.isEmpty)
    }

    @Test func aClickOutsideThePageDeselects() {
        var workspace = Self.cards()
        workspace.selectItem("node-2")
        workspace.gesture(.move, pt(1500, 1100), pt(1500, 1100))
        #expect(workspace.selectedNodeIDs.isEmpty)
    }

    @Test func aDragOfASelectedLayerMovesBothAsOneStep() {
        var workspace = Self.aAndB()
        for x in stride(from: 160.0, through: 190, by: 10) { workspace.drag(from: pt(150, 140), to: pt(x, 140)) }
        workspace.endDrag()
        #expect(workspace.frame("node-2") == rc(140, 100, 100, 80))
        #expect(workspace.frame("node-3") == rc(340, 140, 200, 80))
        #expect(workspace.history.undo.count == 1)
        #expect(workspace.undoActionName == "Undo Move")
        #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
        workspace.undo()
        #expect(workspace.pages == Self.cards().pages)
    }

    @Test func theBoxsBottomRightHandleResizesBothAsOneStep() {
        var workspace = Self.aAndB()
        #expect(workspace.boxHandle(at: pt(500, 220)) == .bottomRight)
        workspace.drag(from: pt(500, 220), to: pt(510, 220))
        workspace.drag(from: pt(500, 220), to: pt(520, 220))
        workspace.endDrag()
        #expect(workspace.frame("node-2") == rc(100, 100, 120, 80))
        #expect(workspace.frame("node-3") == rc(300, 140, 220, 80))
        #expect(workspace.history.undo.count == 1)
        #expect(workspace.undoActionName == "Undo Resize")
    }

    @Test func twoDragsOfTheSameLayersAreTwoSteps() {
        var workspace = Self.aAndB()
        workspace.gesture(.move, pt(150, 140), pt(190, 140))
        workspace.gesture(.move, pt(190, 140), pt(230, 140))
        #expect(workspace.history.undo.count == 2)
    }

    @Test func aMoveFed120SamplesEqualsItsLastSampleAlone() {
        var streamed = Self.aAndB()
        for step in 1...120 { streamed.drag(from: pt(150, 140), to: pt(150 + Double(step), 140 + Double(step % 7))) }
        streamed.endDrag()
        var last = Self.aAndB()
        last.drag(from: pt(150, 140), to: pt(270, 140 + Double(120 % 7)))
        last.endDrag()
        #expect(streamed == last)
        #expect(streamed.history.undo.count == 1)
    }

    @Test func aDragBackToItsStartLeavesNoStep() {
        var workspace = Self.aAndB()
        workspace.drag(from: pt(150, 140), to: pt(190, 140))
        workspace.drag(from: pt(150, 140), to: pt(150, 140))
        workspace.endDrag()
        #expect(workspace.history.undo.isEmpty)
        #expect(workspace.pages == Self.cards().pages)
    }

    @Test func testGesturesWalk() {
        var workspace = Self.cards()
        // Marquee inside Desktop: A and B.
        workspace.gesture(.move, pt(80, 80), pt(520, 240))
        #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
        #expect(workspace.history.undo.isEmpty)
        // Drag A 40 pt right: one Move for both.
        workspace.gesture(.move, pt(150, 140), pt(190, 140))
        #expect(workspace.frame("node-2")?.x == 140)
        #expect(workspace.frame("node-3")?.x == 340)
        #expect(workspace.history.undo.count == 1)
        #expect(workspace.undoActionName == "Undo Move")
        // The box (140, 100)–(540, 220): its bottom-right handle out 20 pt is one Resize.
        workspace.gesture(.move, pt(540, 220), pt(560, 220))
        #expect(workspace.history.undo.count == 2)
        #expect(workspace.undoActionName == "Undo Resize")
        // Option-drag A by (0, 100) in five steps: one Duplicate and two A's.
        workspace.selectItem("node-2")
        for step in 1...5 { workspace.drag(from: pt(150, 140), to: pt(150, 140 + Double(step) * 20), modifiers: .option) }
        workspace.endDrag()
        #expect(workspace.history.undo.count == 3)
        #expect(workspace.undoActionName == "Undo Duplicate")
        #expect(workspace.selectedPage?.nodes.first?.children.filter { $0.name == "A" }.count == 2)
        // A marquee over Locked and Hidden selects nothing.
        workspace.drag(from: pt(390, 590), to: pt(710, 710))
        #expect(workspace.marquee != nil)
        #expect(workspace.selectedNodeIDs.isEmpty)
        workspace.endDrag()
        #expect(workspace.marquee == nil)
        #expect(workspace.selectedNodeIDs.isEmpty)
        #expect(workspace.history.undo.count == 3)
    }
}
