// TimelineBudgetTests.swift: the timeline's quality budgets that run without
// a window (timeline packet, Quality tests). QB-S11: the ruler's marks and
// label placements for 4,096 pt of a 100,000-frame timeline cost at most
// 0.2 ms, gated at 2 ms, because they're bounded by the visible width and
// never by the duration. The best of several runs is gated, so a busy machine
// doesn't fail it. No SwiftUI. macOS only.
import Foundation
import SuiteUI
import Testing

@Suite struct TimelineBudgetTests {
    @Test func rulerMarksFor4096PointsOf100000FramesStayInBudget() {
        let mapping = FrameMapping(duration: 100_000, frameWidth: 10)
        // The middle of the timeline, and its far end, where the numbers are widest.
        let stretches = [500_000.0...504_096.0, mapping.contentWidth - 4_096...mapping.contentWidth]
        var best = Duration.seconds(1)
        var drawn = 0
        for _ in 0..<20 {
            let clock = ContinuousClock()
            let elapsed = clock.measure {
                for stretch in stretches {
                    let marks = mapping.rulerMarks(
                        visibleX: stretch, tickSpacing: Double(SuiteSize.timelineTickSpacing),
                        labelSpacing: Double(SuiteSize.timelineLabelSpacing),
                        digitWidth: Double(SuiteSize.timelineLabelDigit)
                    )
                    let placed = mapping.rulerLabels(
                        marks.labels, digitWidth: Double(SuiteSize.timelineLabelDigit),
                        padding: Double(SuiteSpacing.xxs), trailingRoom: Double(SuiteSpacing.xl)
                    )
                    drawn = marks.ticks.count + placed.count
                }
            }
            best = min(best, elapsed / stretches.count)
        }
        #expect(drawn > 0)
        #expect(drawn < 4_096, "marks are bounded by the width, not the duration")
        #expect(best <= .milliseconds(2), "QB-S11: \(best) for 4,096 pt of ruler (target 0.2 ms)")
    }
}
