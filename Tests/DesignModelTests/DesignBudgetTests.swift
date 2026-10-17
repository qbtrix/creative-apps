// DesignBudgetTests.swift: the shared budget rows QD-S8, QD-S9 and QD-S11
// (docs/blueprints/design.md section 7.1; packet
// docs/blueprints/design/features/design-seams.md, D0-4b), on `crowd` (2,000
// layers on one page). Each row times 200 runs through DesignBudget and fails
// when the p95 is over the Linux debug gate (10 × the device target):
// QD-S8, one hit test per pointer move, ≤ 0.5 ms / ≤ 5 ms; QD-S9, one document
// edit (`apply` plus one history record), ≤ 1 ms / ≤ 10 ms; QD-S11, encode and
// decode the crowd file, ≤ 50 ms / ≤ 500 ms. Each also checks the timed body did
// its work, so a body that short-circuits can't pass.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import Testing

@Suite struct DesignBudgetTests {
    /// Points a pointer passes over on `crowd`: Frame 1's Rectangle 1, the backmost leaf, so the
    /// walk visits every layer before it; Frame 40's Text, the frontmost; a frame's margin; and
    /// empty canvas, a miss that walks all 2,000.
    private static let pointerPath: [(DesignPoint, String?)] = [
        (DesignPoint(x: 13, y: 13), "node-2"),
        (DesignPoint(x: 1240, y: 945), "node-2000"),
        (DesignPoint(x: 11, y: 11), "node-1"),
        (DesignPoint(x: 1430, y: 1010), nil),
    ]

    @Test func hitTest() {
        let workspace = DesignFixtures.crowd
        for (point, expected) in Self.pointerPath {
            #expect(workspace.hitTest(point) == expected, "hit at \(point)")
        }
        let gate = DesignBudget.linuxDebugGate(device: .microseconds(500))
        var move = 0
        var hits = 0
        let report = DesignBudget.expect("QD-S8 hit test on crowd", runs: 200, gate: gate) {
            let (point, expected) = Self.pointerPath[move % Self.pointerPath.count]
            move += 1
            if workspace.hitTest(point) == expected { hits += 1 }
        }
        #expect(move == 200 && hits == 200, "the timed moves hit \(hits) of \(move) as expected")
        #expect(report.median <= gate, "QD-S8 hit test on crowd: \(report), median over the gate \(gate)")
    }

    @Test func applyStep() throws {
        var workspace = DesignFixtures.crowd
        let nodes = try #require(workspace.selectedPage?.nodes)
        // Two edits that move Frame 1's Rectangle 1 one point apart, so every apply changes the page.
        func moved(by dx: Double) -> DesignEdit {
            var edited = nodes
            if var frame = edited.first, !frame.children.isEmpty {
                frame.children[0].frame.x += dx
                edited[0] = frame
            }
            return DesignEdit(name: "Move", nodes: edited, selection: ["node-2"])
        }
        let edits = [moved(by: 1), moved(by: 0)]
        let gate = DesignBudget.linuxDebugGate(device: .milliseconds(1))
        var step = 0
        let report = DesignBudget.expect("QD-S9 apply step on crowd", runs: 200, gate: gate) {
            workspace.apply(edits[step % 2])
            step += 1
        }
        #expect(step == 200, "the timed edits ran \(step) steps, not 200")
        #expect(workspace.history.undo.count == DesignHistory.limit, "each apply did not record one step")
        #expect(workspace.history.undo.last?.name == "Move")
        #expect(workspace.selectedPage?.nodes == edits[1].nodes)
        #expect(report.median <= gate, "QD-S9 apply step on crowd: \(report), median over the gate \(gate)")
    }

    @Test func fileRoundTrip() throws {
        let crowd = DesignFixtures.crowd
        let expected = try crowd.fileData()
        let gate = DesignBudget.linuxDebugGate(device: .milliseconds(50))
        var reopened = DesignWorkspace()
        var trips = 0
        let report = try DesignBudget.expect("QD-S11 file round trip on crowd", runs: 200, gate: gate) {
            let data = try crowd.fileData()
            reopened = DesignWorkspace()
            try reopened.open(data)
            trips += 1
        }
        #expect(trips == 200, "the timed round trips ran \(trips), not 200")
        #expect(reopened.pages == crowd.pages, "the round trip changed the document")
        #expect(try reopened.fileData() == expected, "the round trip changed the file bytes")
        #expect(report.median <= gate, "QD-S11 file round trip on crowd: \(report), median over the gate \(gate)")
    }
}
