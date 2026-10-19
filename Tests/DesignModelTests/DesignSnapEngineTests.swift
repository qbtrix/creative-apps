// DesignSnapEngineTests.swift: journey MJ10 `walkEngine` (snapping SN-e) on the
// `cards` fixture. Design's candidates feed the kernel's snap engines: A's box
// near B's left edge and C's top snaps by (2.6, -0.4) from the lines; C's box at
// x 603 snaps -3 to an equal gap; B's box near the middle centres between A and
// C; and the gaps and spacing hints at each snapped place. SN-1 wrote it
// disabled; SN-3 turned it on. Runs on Linux and macOS.
import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignSnapEngineTests {
    /// The snap reach in document points at 200 % zoom (8 screen points).
    static let tolerance = 4.0

    func near(_ value: Double?, _ expected: Double) -> Bool {
        guard let value else { return false }
        return abs(value - expected) < 1e-9
    }

    func edges(_ box: Rect, _ axis: DesignSnapLine.Axis) -> [Double] {
        axis == .x ? [box.minX, (box.minX + box.maxX) / 2, box.maxX] : [box.minY, (box.minY + box.maxY) / 2, box.maxY]
    }

    @Test func walkEngine() {
        let cards = DesignFixtures.cards

        // A, dragged to (297.4, 100.4): its left edge lines up with B's at x 300, its top with C's at y 100.
        let forA = cards.snapCandidates(moving: ["node-2"], drawingInto: nil)
        let lines = SnapLines(forA)
        let dragged = Rect(minX: 297.4, minY: 100.4, maxX: 397.4, maxY: 180.4)
        #expect(near(lines.offset(.x, for: edges(dragged, .x), tolerance: Self.tolerance), 2.6))
        #expect(near(lines.offset(.y, for: edges(dragged, .y), tolerance: Self.tolerance), -0.4))
        let snapped = Rect(minX: 300, minY: 100, maxX: 400, maxY: 180)
        let onLines = DesignSnapGuides(lines: lines.lines(on: snapped)).summary
        #expect(onLines.contains("x 300") && onLines.contains("y 100"))

        // A where it sits: 100 to B on x, 28 below Title on y.
        let home = Rect(minX: 100, minY: 100, maxX: 200, maxY: 180)
        let aroundA = DesignSnapGuides(gaps: SnapGaps(forA).gaps(around: home)).summary
        #expect(aroundA.contains("gap x 100") && aroundA.contains("gap y 28"))

        // C at x 603: -3 makes its gap to B equal B's gap to A (100).
        let forC = cards.snapCandidates(moving: ["node-4"], drawingInto: nil)
        let gaps = SnapGaps(forC)
        let c = Rect(minX: 603, minY: 100, maxX: 703, maxY: 220)
        #expect(near(gaps.spacingOffset(.x, for: c, tolerance: Self.tolerance), -3))
        let atEqual = gaps.gaps(around: Rect(minX: 600, minY: 100, maxX: 700, maxY: 220))
        #expect(atEqual.filter { $0.isSpacing && $0.axis == .x && $0.length == 100 }.count == 2)
        #expect(DesignSnapGuides(gaps: atEqual).summary.contains("spacing x 100"))

        // B at x 348.6: +1.4 centres it between A and C, 150 each side.
        let forB = cards.snapCandidates(moving: ["node-3"], drawingInto: nil)
        let b = Rect(minX: 348.6, minY: 140, maxX: 548.6, maxY: 220)
        #expect(near(SnapGaps(forB).spacingOffset(.x, for: b, tolerance: Self.tolerance), 1.4))
    }
}
