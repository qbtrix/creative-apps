// DesignExportBudgetTests.swift: QD-S12's SVG half (packet design-export, DE-5): the SVG of
// the `crowd` page (2,000 layers) takes ≤ 100 ms on a device, so ≤ 1 s under the Linux debug
// gate (10 × the target). The gate reads the median of the runs, so one slow run on a busy
// worker doesn't fail it. `svgExportAtFrame` (one-document OD-9): `animated(500)`'s page at frame 60 holds the same
// gate, the sampling included. Runs on Linux and macOS. The test is timed, so the suite is on the
// perf list (Tests/perf-suites.txt): the merge gate skips it and perf-nightly runs it.
import DesignModel
import Testing

@Suite struct DesignExportBudgetTests {
    @Test func svgExport() throws {
        var workspace = DesignFixtures.crowd
        workspace.useServices(.live)
        let plan = try workspace.exportPlan(DesignExportOptions(format: .svg, scope: .page), existing: [])
        let item = try #require(plan.first)
        var length = 0
        let report = try DesignBudget.measure(runs: 5) { length = try workspace.exportSVG(item).utf8.count }
        #expect(length > 2_000 * 40, "the crowd page's SVG is \(length) bytes, too short for 2,000 layers")
        let gate = DesignBudget.linuxDebugGate(device: .milliseconds(100))
        #expect(report.median <= gate, "QD-S12 SVG of crowd: \(report), median over the gate \(gate)")
    }

    @Test func svgExportAtFrame() throws {
        var workspace = DesignFixtures.animated(500)
        workspace.useServices(.live)
        let plan = try workspace.exportPlan(DesignExportOptions(format: .svg, scope: .page), existing: [])
        let item = try #require(plan.first)
        var length = 0
        let report = try DesignBudget.measure(runs: 5) { length = try workspace.exportSVG(item, at: 60).utf8.count }
        #expect(length > 500 * 40, "animated(500)'s SVG at frame 60 is \(length) bytes, too short for 500 layers")
        let gate = DesignBudget.linuxDebugGate(device: .milliseconds(100))
        #expect(report.median <= gate, "QD-S12 SVG of animated(500) at frame 60: \(report), median over the gate \(gate)")
    }
}
