// FlareAnchorBudgetTests.swift (pen-paths FP-7 writes it, FP-8 turns it on): selecting and moving 5,000 anchors of one
// shape stays in budget on Linux. Disabled until the stress document lands with branch test/stress-perf-journeys.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

@Suite(.serialized) struct FlareAnchorBudgetTests {
    @Test(.disabled("waits on FP-8: branch test/stress-perf-journeys")) func fiveThousandAnchorsSelectAndMoveInBudget() throws {
        var workspace = FlareAnchorEditTests.picked()
        let points = (0..<5_000).map { Point(x: Double($0 % 100) * 2, y: Double($0 / 100) * 2) }
        try workspace.setPath(VectorPath(elements: [.move(to: Point(x: 0, y: 0))] + points.map { .line(to: $0) }),
                              name: "Edit Path", drag: nil)
        let clock = ContinuousClock(), start = clock.now
        workspace.runPath(.select(anchors: nil, rect: Rect(minX: -1, minY: -1, maxX: 400, maxY: 400), extend: false))
        workspace.runPath(.move(dx: 5, dy: 5, drag: nil))
        let spent = clock.now - start
        #expect(workspace.anchorSelection.ordered.count == 5_001 && spent < .milliseconds(250), "\(spent)")
    }
}
