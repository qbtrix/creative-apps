// RulerLabelWidthTests.swift: ruler labels sit far enough apart for their
// widest frame number, so 8-digit and longer labels never overlap (#220).
// No SwiftUI. macOS only.
import SuiteUI
import Testing

/// The least gap between consecutive labels, in points.
private func smallestGap(_ mapping: FrameMapping, _ labels: [Int]) -> Double {
    zip(labels, labels.dropFirst()).map { mapping.x(forFrame: $1) - mapping.x(forFrame: $0) }.min() ?? .infinity
}

@Test func rulerLabelsLeaveRoomForNineteenDigits() {
    let mapping = FrameMapping(duration: .max, frameWidth: 1e-15)
    let marks = mapping.rulerMarks(visibleX: 0...9000, tickSpacing: 6, labelSpacing: 48, digitWidth: 7)
    #expect(marks.labels.count >= 2)
    #expect(smallestGap(mapping, marks.labels) >= 19 * 7)
}

@Test func rulerLabelsLeaveRoomForTenDigits() {
    let mapping = FrameMapping(duration: 1_000_000_000, frameWidth: 0.00001)
    let marks = mapping.rulerMarks(visibleX: 0...10_000, tickSpacing: 6, labelSpacing: 48, digitWidth: 7)
    #expect(marks.labels.count >= 2)
    #expect(smallestGap(mapping, marks.labels) >= 10 * 7)
}

@Test func rulerLabelsLeaveRoomForEightDigits() {
    let mapping = FrameMapping(duration: 99_999_999, frameWidth: 0.0001)
    let marks = mapping.rulerMarks(visibleX: 0...9000, tickSpacing: 6, labelSpacing: 48, digitWidth: 7)
    #expect(smallestGap(mapping, marks.labels) >= 8 * 7)
}

@Test func shortRulerLabelsKeepTheSpacingFloor() {
    let mapping = FrameMapping(duration: 120, frameWidth: 10)
    let marks = mapping.rulerMarks(visibleX: 0...1200, tickSpacing: 6, labelSpacing: 48, digitWidth: 7)
    #expect(marks.labels == Array(stride(from: 0, through: 120, by: 5)))
}

@Test func labelWidthCountsTheLastVisibleFrame() {
    let mapping = FrameMapping(duration: 1_000_000, frameWidth: 1)
    #expect(mapping.labelWidth(in: 0...99, digitWidth: 7) == 3 * 7)
    #expect(mapping.labelWidth(in: 0...5_000_000, digitWidth: 7) == 8 * 7)
}

@Test func labelWidthIgnoresSillyDigitWidths() {
    let mapping = FrameMapping(duration: .max, frameWidth: 1)
    for digit in [0, -7, .nan, .infinity] {
        #expect(mapping.labelWidth(in: 0...9000, digitWidth: digit) == 0)
    }
    #expect(FrameMapping(duration: .max, frameWidth: 0).labelWidth(in: 0...9000, digitWidth: 7) == 2 * 7)
}
