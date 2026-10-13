// RulerLabelPlacementTests.swift: a ruler label that would run past the
// strip's trailing edge ends at its tick instead, so the last label is drawn
// whole (#61). No SwiftUI. macOS only.
import SuiteUI
import Testing

/// The sample strip: 120 frames at 10 pt, labels every 5 frames.
private let mapping = FrameMapping(duration: 120, frameWidth: 10)
private let labels = Array(stride(from: 0, through: 120, by: 5))

@Test func lastRulerLabelEndsAtItsTick() {
    let placed = mapping.rulerLabels(labels, digitWidth: 7, padding: 2, trailingRoom: 16)
    #expect(placed.last == RulerLabel(frame: 120, endsAtTick: true))
    #expect(placed.dropLast().allSatisfy { !$0.endsAtTick })
    #expect(placed.map(\.frame) == labels)
}

@Test func everyRulerLabelStaysInsideTheStrip() {
    let placed = mapping.rulerLabels(labels, digitWidth: 7, padding: 2, trailingRoom: 16)
    for label in placed {
        let width = Double(String(label.frame).count) * 7
        let tick = mapping.x(forFrame: label.frame)
        let end = label.endsAtTick ? tick - 2 : tick + 2 + width
        #expect(end <= mapping.contentWidth + 16)
    }
}

@Test func aLabelThatFitsKeepsStartingAtItsTick() {
    let placed = mapping.rulerLabels([120], digitWidth: 7, padding: 2, trailingRoom: 40)
    #expect(placed == [RulerLabel(frame: 120, endsAtTick: false)])
}

@Test func aLabelThatWouldRunIntoTheLastOneIsDropped() {
    // 10-digit labels 100 pt apart: the one before the last would overlap it.
    let long = FrameMapping(duration: 1_000_000_100, frameWidth: 1)
    let placed = long.rulerLabels([1_000_000_000, 1_000_000_100], digitWidth: 7, padding: 2, trailingRoom: 16)
    #expect(placed == [RulerLabel(frame: 1_000_000_100, endsAtTick: true)])
}

@Test func rulerLabelsIgnoreSillyDigitWidths() {
    for digit in [0, -7, .nan, .infinity] {
        let placed = mapping.rulerLabels(labels, digitWidth: digit, padding: 2, trailingRoom: 16)
        #expect(placed.map(\.frame) == labels)
        #expect(placed.allSatisfy { !$0.endsAtTick })
    }
}
