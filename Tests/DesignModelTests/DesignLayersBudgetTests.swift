// DesignLayersBudgetTests.swift: QD-S10's model half (docs/blueprints/design.md
// section 7.1; packet docs/blueprints/design/features/layers-panel.md, L-7).
// On `crowd` with all 40 frames expanded, the Layers list's rows are 2,000
// (40 frames at depth 0, each with its 49 children at depth 1, frontmost
// first), and building them through `layerRows` takes ≤ 5 ms on a device, so
// ≤ 50 ms under the Linux debug gate (DesignBudget.linuxDebugGate). The gate
// reads the median of the runs, not one sample, so a single slow run on a
// busy worker doesn't fail it. P3 (`testLayerListScroll`) is the screen half.
import DesignModel
import Testing

@Suite struct DesignLayersBudgetTests {
    /// `crowd` with every frame's row expanded, as P3 scrolls it.
    private func expandedCrowd() throws -> DesignWorkspace {
        var workspace = DesignFixtures.crowd
        for frame in workspace.selectedPage?.nodes ?? [] { try workspace.setExpanded(frame.id, true) }
        return workspace
    }

    @Test func expandedCrowdListsTwoThousandRows() throws {
        let rows = try expandedCrowd().layerRows
        #expect(rows.count == 2_000)
        #expect(rows.filter { $0.depth == 0 }.count == 40)
        #expect(rows.filter { $0.depth == 1 }.count == 1_960)
        // Frontmost first: Frame 40 heads the list, its Text first under it; Frame 1's Rectangle 1 ends it.
        #expect(rows.first?.node.name == "Frame 40")
        #expect(rows.dropFirst().first?.node.name == "Text")
        #expect(rows.last?.node.name == "Rectangle 1")
        #expect(Set(rows.map(\.id)).count == 2_000)
    }

    @Test func layerRows() throws {
        let workspace = try expandedCrowd()
        let gate = DesignBudget.linuxDebugGate(device: .milliseconds(5))
        var built = 0
        let report = DesignBudget.measure(runs: 15) { built = workspace.layerRows.count }
        #expect(built == 2_000, "the timed build listed \(built) rows, not 2,000")
        #expect(report.median <= gate, "QD-S10 layerRows on expanded crowd: \(report), median over the gate \(gate)")
    }
}
