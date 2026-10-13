// RulerLabelSweepTests.swift: rulerMarks over durations of 1 to 19 digits,
// frame widths that put the strip anywhere from a few points to 1e9 points
// wide, and visible stretches across the whole strip. Consecutive labels
// always leave room for the earlier one's digits plus the 2 pt text offset,
// and stay ascending inside the stretch (#220). No SwiftUI. macOS only.
import SuiteUI
import Testing

private let sweepDurations = [
    9, 99, 999, 9_999, 99_999, 999_999, 9_999_999, 99_999_999, 999_999_999,
    10_000_000_000, 123_456_789_012, 99_999_999_999_999, Int.max / 1000, Int.max,
]

private let sweepContentWidths: [Double] = [100, 1_000, 10_000, 1e6, 1e9]

private let sweepViewWidths: [Double] = [50, 320, 1_200, 4_096]

@Test(arguments: sweepDurations)
func rulerLabelsNeverOverlapAcrossTheStrip(duration: Int) {
    for content in sweepContentWidths {
        let mapping = FrameMapping(duration: duration, frameWidth: content / Double(duration))
        for view in sweepViewWidths {
            for fraction in [0, 0.1, 0.333, 0.5, 0.9, 0.999, 1] {
                let low = max(mapping.contentWidth - view, 0) * fraction
                let visible = low...(low + view)
                let labels = mapping.rulerMarks(visibleX: visible, tickSpacing: 6, labelSpacing: 48, digitWidth: 7).labels
                #expect(labels == labels.sorted())
                #expect(labels.allSatisfy { visible.contains(mapping.x(forFrame: $0)) })
                for (earlier, later) in zip(labels, labels.dropFirst()) {
                    let gap = mapping.x(forFrame: later) - mapping.x(forFrame: earlier)
                    #expect(gap >= Double(String(earlier).count) * 7 + 2, "\(duration) \(content) \(earlier) \(later)")
                }
            }
        }
    }
}

@Test func zeroDigitWidthKeepsTheFixedSpacing() {
    let mapping = FrameMapping(duration: 1_000_000_000, frameWidth: 0.00001)
    let plain = mapping.rulerMarks(visibleX: 0...10_000, tickSpacing: 6, labelSpacing: 48)
    #expect(mapping.rulerMarks(visibleX: 0...10_000, tickSpacing: 6, labelSpacing: 48, digitWidth: 0) == plain)
    #expect(plain.labels.contains(5_000_000))
}
