// PenRulesTests.swift (pen-paths PN-1 written, PN-5 turns on): Flare's Pen rules, tolerances on screen.
import Testing
import SuiteKernel
@Suite struct PenRulesTests {
    /// The draft after a press at each point, at `scale`.
    static func draft(_ points: [(Double, Double)], scale: Double = 1) -> PenDraft? {
        points.reduce(nil) { d, p in PenRules.add(Point(x: p.0, y: p.1), handleOut: nil, to: d, scale: scale) }
    }
    @Test func closeAddsNoPoint() throws {
        let d = try #require(Self.draft([(100, 100), (300, 100), (300, 300)], scale: 0.4))
        #expect(PenRules.closes(Point(x: 105, y: 100), d) && PenRules.closed(d).contour.closed && PenRules.closed(d).contour.anchors.count == 3)
    }
    @Test func closeIsInclusive() throws {
        let d = try #require(Self.draft([(0, 0), (100, 0), (100, 100)], scale: 2))
        #expect(PenRules.closes(Point(x: 4.0 / 2, y: 0), d) && !PenRules.closes(Point(x: 4.01 / 2, y: 0), d))
    }
    @Test func toleranceIsOnScreen() {
        #expect(Self.draft([(20, 20), (25, 20), (25.1, 20)], scale: 8)?.contour.anchors.count == 2)
        #expect(Self.draft([(20, 20), (25, 20), (25.2, 20)], scale: 8)?.contour.anchors.count == 3)
    }
    @Test func cornerThenSmoothIsOneCubic() throws {
        let d = PenRules.add(Point(x: 100, y: 0), handleOut: Point(x: 130, y: 30), to: Self.draft([(0, 0)]), scale: 1)
        #expect(d.contour.anchors.last?.handleIn == Point(x: 70, y: -30) && d.contour.anchors.last?.kind == .symmetric)
        // A path keeps no kinds (its view re-measures them), so the cubic is the check: the corner's control at its point.
        let elements = try PenRules.path(d).elements
        guard elements.count == 2, case .cubic(let c1, let c2, let to) = elements[1] else { Issue.record("\(elements)"); return }
        #expect(c1 == Point(x: 0, y: 0) && c2 == Point(x: 70, y: -30) && to == Point(x: 100, y: 0))
    }
    @Test func finishHelpReadsFlaresReasons() {
        #expect(PenRules.finishHelp(nil) == "Click with the Pen to start a path.")
        #expect(PenRules.finishHelp(Self.draft([(0, 0)])) == "Click a second point to finish the path.")
        #expect(PenRules.finishHelp(Self.draft([(0, 0), (50, 0)])) == nil)
    }
    @Test func degenerateThrows() throws {
        let d = try #require(Self.draft([(3, 3), (3.5, 3)]))
        #expect(throws: (any Error).self) { try PenRules.path(d) }
    }
}
