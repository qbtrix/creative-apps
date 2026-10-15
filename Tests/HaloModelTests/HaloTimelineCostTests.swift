// HaloTimelineCostTests.swift: the timeline's quality bar (QB-L10, model half,
// docs/review-rubric.md): building the strip's rows for 300 layers, which the
// viewer does on every scrub, and one scrub step (QB-L3's model side) each stay
// under 5 ms in release and 50 ms in debug (CI); so do HB-6's rows on the
// `crowd` fixture (300 layers, 5,000 keys, key frames included). The quietest
// p95 of three rounds of 100 counts, since scripts/ci runs suites in parallel.
@testable import HaloModel
import Testing

#if DEBUG
private let budget = Duration.milliseconds(50)
#else
private let budget = Duration.milliseconds(5)
#endif

/// The quietest p95 of three rounds of 100 runs of `work`.
private func p95(_ name: String, _ work: () -> Void) -> Duration {
    let clock = ContinuousClock()
    var p95s: [Duration] = []
    for _ in 0..<3 {
        var costs = (0..<100).map { _ in clock.measure(work) }
        costs.sort()
        p95s.append(costs[94])
        print("HaloTimelineCost \(name) p50 \(costs[49]) p95 \(costs[94]) budget \(budget)")
    }
    return p95s.min() ?? budget * 2
}

struct HaloTimelineCostTests {
    @Test func rowsAndScrubFor300LayersUnderBudget() {
        var project = HaloProject()
        project.newComposition(CompositionSettings(name: "Big", framesPerSecond: 30, durationSeconds: 60))
        for i in 0..<300 { project.newLayer(HaloLayerKind.allCases[i % 4]) }
        var rows: [HaloTimelineRow] = []
        #expect(p95("rows") { rows = project.timelineRows } <= budget)
        #expect(rows.count == 300)
        #expect(rows.first?.isSelected == true)
        #expect(p95("scrub") { project.scrub(to: 2000) } <= budget)
        #expect(project.selectedComposition?.playheadFrame == 1799)
    }

    /// HB-6 (blueprint 7.1): the rows, key frames included, for `crowd`.
    @Test func timelineRowsCrowd() throws {
        var project = HaloProject(services: .fake)
        project.restore(try #require(HaloFixtures.project("crowd")))
        var rows: [HaloTimelineRow] = []
        #expect(p95("crowd") { rows = project.timelineRows } <= budget)
        #expect(rows.count == 300)
        #expect(rows.first?.keyFrames == Array(stride(from: 0, to: 300, by: 30)))
        #expect(rows.last?.keyFrames == [])
    }
}
