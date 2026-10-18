// DesignWholePointsTests.swift: draws, moves (one layer or several, a frame
// with its children) and resizes on the canvas land on whole points at any zoom
// (canvas-basics CB-2, packet docs/blueprints/design/features/canvas-basics.md,
// the CB-2 acceptance row), and walk MJ9. Typed values and nudges keep their
// fractions. On `cards` with the live services: A is node-2 at (100, 100, 100, 80),
// B node-3 at (300, 140, 200, 80), both inside Desktop (node-1). Runs on Linux and macOS.
import DesignModel
import Testing

private let (desktop, a, b) = ("node-1", "node-2", "node-3")

/// Whether every edge of `frame` sits on a whole point.
private func onWholePoints(_ frame: DesignRect?) -> Bool {
    guard let frame else { return false }
    return [frame.x, frame.y, frame.maxX, frame.maxY].allSatisfy { $0 == $0.rounded() }
}

private func near(_ lhs: Double, _ rhs: Double) -> Bool { (lhs - rhs).magnitude < 1e-9 }

/// `cards` plus a frame at (820.3, 450.6, 200, 100) inside Desktop holding a rectangle at
/// (830.3, 460.6, 20, 10); the frame is selected. Returns the workspace and both ids.
private func cardsWithFractionalFrame() throws -> (DesignWorkspace, frame: String, child: String) {
    var workspace = DesignFixtures.cards
    let frame = try workspace.addNode(.frame, frame: rc(820.3, 450.6, 200, 100), in: desktop)
    let child = try workspace.addNode(.rectangle, frame: rc(830.3, 460.6, 20, 10), in: frame)
    workspace.selectItem(frame)
    return (workspace, frame, child)
}

@Suite struct DesignWholePointsTests {
    @Test func aPointRoundsToTheNearestWholePointHalfUp() {
        #expect(pt(100.3, 200.7).wholePoints == pt(100, 201))
        #expect(pt(0.5, -0.5).wholePoints == pt(1, 0))
        #expect(pt(-2.5, 2.5).wholePoints == pt(-2, 3))
        #expect(pt(-7.8, 13.4).wholePoints == pt(-8, 13))
        let open = pt(.infinity, -.infinity).wholePoints
        #expect(open == pt(.infinity, -.infinity))
        #expect(pt(.nan, 1.2).wholePoints.x.isNaN)
    }

    @Test func aRectangleRoundsEachEdgeAndKeepsBothSidesAtLeastOne() {
        // The far edge rounds, not the width: 100.4 + 100.4 = 200.8 ends at 201.
        #expect(rc(100.4, 0, 100.4, 1).wholePoints == rc(100, 0, 101, 1))
        #expect(rc(94.5, 99.6, 111, 80.8).wholePoints == rc(95, 100, 111, 80))
        #expect(rc(10.2, 10.2, 0.1, 0.2).wholePoints == rc(10, 10, 1, 1))
        #expect(rc(3, 4, 5, 6).wholePoints == rc(3, 4, 5, 6))
    }

    @Test func aDrawnRectangleLandsOnWholePoints() {
        var workspace = DesignFixtures.cards
        workspace.gesture(.rectangle, pt(100.3, 200.7), pt(219.6, 280.2))
        let id = workspace.selectedNodeID ?? ""
        #expect(workspace.frame(id) == rc(100, 201, 120, 79))
        #expect(workspace.undoActionName == "Undo Add Rectangle")
    }

    @Test func shiftDrawsAWholeSquare() {
        var workspace = DesignFixtures.cards
        workspace.gesture(.rectangle, pt(100.3, 200.7), pt(160.2, 230.1), [.shift])
        #expect(workspace.frame(workspace.selectedNodeID ?? "") == rc(100, 201, 60, 60))
    }

    @Test func aClickDrawsTheDefaultSizeAtAWholeStart() {
        var workspace = DesignFixtures.cards
        workspace.gesture(.ellipse, pt(600.4, 700.6), pt(600.4, 700.6))
        let frame = workspace.frame(workspace.selectedNodeID ?? "")
        #expect(frame?.x == 600)
        #expect(frame?.y == 701)
    }

    @Test func aMovedLayerLandsOnWholePoints() {
        var workspace = DesignFixtures.cards
        workspace.gesture(.move, pt(150, 140), pt(163.4, 132.2))
        #expect(workspace.frame(a) == rc(113, 92, 100, 80))
        #expect(workspace.undoActionName == "Undo Move")
    }

    @Test func aFrameMovesOntoWholePointsAndItsChildrenKeepTheirOffsets() throws {
        var (workspace, frame, child) = try cardsWithFractionalFrame()
        workspace.gesture(.move, pt(850, 520), pt(890, 520))
        #expect(workspace.frame(frame) == rc(860, 451, 200, 100))
        let moved = try #require(workspace.frame(child))
        #expect(near(moved.x, 830.3 + 39.7))
        #expect(near(moved.y, 460.6 + 0.4))
        #expect(near(moved.x - 860, 830.3 - 820.3))
    }

    @Test func aClickOnAFractionalLayerChangesNothing() throws {
        var (workspace, frame, _) = try cardsWithFractionalFrame()
        let before = workspace.pages
        workspace.gesture(.move, pt(850, 520), pt(850, 520))
        #expect(workspace.pages == before)
        #expect(workspace.frame(frame) == rc(820.3, 450.6, 200, 100))
    }

    @Test func severalLayersMoveTogetherWithTheBoxOnWholePoints() {
        var workspace = DesignFixtures.cards
        workspace.selectItem(a)
        workspace.toggleSelection(b)
        workspace.gesture(.move, pt(150, 140), pt(163.4, 132.2))
        #expect(workspace.frame(a) == rc(113, 92, 100, 80))
        #expect(workspace.frame(b) == rc(313, 132, 200, 80))
        #expect(workspace.selectionBounds == rc(113, 92, 400, 120))
    }

    @Test func theBottomRightHandleResizesOntoWholePoints() {
        var workspace = DesignFixtures.cards
        workspace.selectItem(a)
        workspace.gesture(.move, pt(200, 180), pt(205.5, 180.4))
        #expect(workspace.frame(a) == rc(100, 100, 106, 80))
        #expect(workspace.undoActionName == "Undo Resize")
    }

    @Test func optionResizesFromTheCentreWithEveryEdgeWhole() {
        var workspace = DesignFixtures.cards
        workspace.selectItem(a)
        workspace.gesture(.move, pt(200, 180), pt(205.5, 180.4), [.option])
        #expect(onWholePoints(workspace.frame(a)))
        #expect(workspace.frame(a) == rc(95, 100, 111, 80))
    }

    @Test func aNudgeKeepsItsFraction() throws {
        var (workspace, frame, _) = try cardsWithFractionalFrame()
        workspace.nudge(.right, shift: false)
        let nudged = try #require(workspace.frame(frame))
        #expect(near(nudged.x, 821.3))
        #expect(near(nudged.y, 450.6))
    }

    @Test func aHundredAndTwentySampleMoveEndsWhereItsLastSampleAloneDoes() {
        var sampled = DesignFixtures.cards
        sampled.selectTool(.move)
        for step in 1...120 {
            let t = Double(step) / 120
            sampled.drag(from: pt(150, 140), to: pt(150 + 13.4 * t, 140 - 7.8 * t))
        }
        sampled.endDrag()
        var once = DesignFixtures.cards
        once.gesture(.move, pt(150, 140), pt(163.4, 132.2))
        #expect(sampled.pages == once.pages)
        #expect(sampled.frame(a) == rc(113, 92, 100, 80))
    }

    /// MJ9: a draw, a move and a resize on `cards`, each ending on whole points; Shift keeps the square whole.
    @Test func walkWholePoints() {
        var workspace = DesignFixtures.cards
        workspace.gesture(.rectangle, pt(100.3, 200.7), pt(219.6, 280.2))
        let id = workspace.selectedNodeID ?? ""
        #expect(workspace.frame(id) == rc(100, 201, 120, 79))

        workspace.gesture(.move, pt(160, 240), pt(173.4, 232.2))
        #expect(workspace.frame(id) == rc(113, 193, 120, 79))
        #expect(workspace.undoActionName == "Undo Move")

        workspace.gesture(.move, pt(233, 272), pt(238.5, 272.4))
        #expect(workspace.frame(id) == rc(113, 193, 126, 79))
        #expect(onWholePoints(workspace.frame(id)))
        #expect(workspace.undoActionName == "Undo Resize")

        workspace.gesture(.rectangle, pt(600.3, 700.7), pt(660.2, 730.1), [.shift])
        let square = workspace.frame(workspace.selectedNodeID ?? "")
        #expect(square == rc(600, 701, 60, 60))
        #expect(onWholePoints(square))
    }
}
