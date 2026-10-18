// ScrubReferenceTests.swift: QB-S27. Sixty reference rows written from
// docs/design.md's number rules (Scrub fields, the bar slider's Input), not
// from the code, run through SuiteValueScrubbing: drag one step per point,
// Shift ×10, Option ×0.1 (Option wins), snapped to the step and clamped; a
// spec with no step takes the largest power of ten not above a hundredth of
// its range; arrows step from the value (Shift coarse, Option fine), Home and
// End jump to the ends; never NaN. No SwiftUI here. macOS only.
import Foundation
import SuiteUI
import Testing

private struct DragRow: Sendable {
    let start: Double, points: Double, modifiers: KeyModifiers, step: Double, range: ClosedRange<Double>
    let expected: Double
}

private struct KeyRow: Sendable {
    let value: Double, key: ScrubKey, modifiers: KeyModifiers, step: Double, range: ClosedRange<Double>
    let expected: Double
}

private let both: KeyModifiers = [.shift, .option]

private let dragRows: [DragRow] = [
    DragRow(start: 0, points: 40, modifiers: [], step: 1, range: 0...360, expected: 40),
    DragRow(start: 0, points: 4, modifiers: .shift, step: 1, range: 0...360, expected: 40),
    DragRow(start: 0, points: 10, modifiers: .option, step: 1, range: 0...360, expected: 1),
    DragRow(start: 50, points: -7, modifiers: [], step: 1, range: 0...100, expected: 43),
    DragRow(start: 90, points: 500, modifiers: [], step: 1, range: 0...100, expected: 100),
    DragRow(start: 10, points: -500, modifiers: [], step: 1, range: 0...100, expected: 0),
    DragRow(start: 12.3, points: 0, modifiers: [], step: 1, range: 0...100, expected: 12),
    DragRow(start: 0, points: 2.6, modifiers: [], step: 5, range: 0...100, expected: 15),
    DragRow(start: 0, points: 3, modifiers: [], step: 0.1, range: -5...5, expected: 0.3),
    DragRow(start: 0.5, points: 7, modifiers: [], step: 0.01, range: 0...1, expected: 0.57),
    DragRow(start: 0, points: 3, modifiers: both, step: 1, range: 0...100, expected: 0.3),
    DragRow(start: 50, points: 25, modifiers: .shift, step: 1, range: 0...100, expected: 100),
    DragRow(start: -180, points: 90, modifiers: [], step: 1, range: -180...180, expected: -90),
    DragRow(start: 0, points: -15, modifiers: [], step: 0.1, range: -5...5, expected: -1.5),
    DragRow(start: 1, points: 5, modifiers: .option, step: 0.1, range: 0...10, expected: 1.05),
    DragRow(start: 0, points: 0, modifiers: [], step: 1, range: 0...100, expected: 0),
    DragRow(start: 200, points: 0, modifiers: [], step: 1, range: 0...100, expected: 100),
    DragRow(start: 0, points: 40, modifiers: [], step: 0, range: 0...100, expected: 40),
    DragRow(start: 0, points: 40, modifiers: [], step: 0, range: 0...1, expected: 0.4),
    DragRow(start: 0, points: 30, modifiers: [], step: -1, range: -5...5, expected: 3),
    DragRow(start: 0, points: 1, modifiers: [], step: .nan, range: 0...100, expected: 1),
    DragRow(start: 5, points: .infinity, modifiers: [], step: 1, range: 0...100, expected: 5),
    DragRow(start: 5, points: .nan, modifiers: [], step: 1, range: 0...100, expected: 5),
    DragRow(start: 72, points: 0.4, modifiers: [], step: 1, range: 0...360, expected: 72),
    DragRow(start: 72, points: 0.6, modifiers: [], step: 1, range: 0...360, expected: 73),
    DragRow(start: 10, points: -3, modifiers: .shift, step: 1, range: 0...100, expected: 0),
    DragRow(start: 0, points: 12, modifiers: [], step: 0.5, range: 0...10, expected: 6),
    DragRow(start: 0.25, points: 1, modifiers: [], step: 0.5, range: 0...10, expected: 1),
    DragRow(start: -2.5, points: 0, modifiers: [], step: 1, range: -5...5, expected: -3),
    DragRow(start: 0, points: 7, modifiers: .option, step: 10, range: 0...1000, expected: 7),
]

private let keyRows: [KeyRow] = [
    KeyRow(value: 72, key: .increment, modifiers: [], step: 1, range: 0...360, expected: 73),
    KeyRow(value: 73, key: .increment, modifiers: [], step: 1, range: 0...360, expected: 74),
    KeyRow(value: 74, key: .increment, modifiers: .shift, step: 1, range: 0...360, expected: 84),
    KeyRow(value: 84, key: .end, modifiers: [], step: 1, range: 0...360, expected: 360),
    KeyRow(value: 360, key: .home, modifiers: [], step: 1, range: 0...360, expected: 0),
    KeyRow(value: 0, key: .decrement, modifiers: [], step: 1, range: 0...360, expected: 0),
    KeyRow(value: 360, key: .increment, modifiers: [], step: 1, range: 0...360, expected: 360),
    KeyRow(value: 45, key: .increment, modifiers: .shift, step: 1, range: 0...360, expected: 55),
    KeyRow(value: 45, key: .decrement, modifiers: .shift, step: 1, range: 0...360, expected: 35),
    KeyRow(value: 45, key: .increment, modifiers: .option, step: 1, range: 0...360, expected: 45.1),
    KeyRow(value: 45, key: .decrement, modifiers: .option, step: 1, range: 0...360, expected: 44.9),
    KeyRow(value: 45, key: .increment, modifiers: both, step: 1, range: 0...360, expected: 45.1),
    KeyRow(value: 12.3, key: .increment, modifiers: [], step: 1, range: 0...360, expected: 13),
    KeyRow(value: 0.5, key: .increment, modifiers: [], step: 0.1, range: 0...1, expected: 0.6),
    KeyRow(value: 0.9, key: .increment, modifiers: [], step: 0.1, range: 0...1, expected: 1),
    KeyRow(value: 1, key: .increment, modifiers: .shift, step: 0.1, range: 0...1, expected: 1),
    KeyRow(value: 0, key: .decrement, modifiers: .shift, step: 0.1, range: -5...5, expected: -1),
    KeyRow(value: -5, key: .decrement, modifiers: [], step: 0.1, range: -5...5, expected: -5),
    KeyRow(value: 10, key: .home, modifiers: [], step: 1, range: -180...180, expected: -180),
    KeyRow(value: 10, key: .end, modifiers: [], step: 1, range: -180...180, expected: 180),
    KeyRow(value: 72, key: .home, modifiers: .shift, step: 1, range: 0...360, expected: 0),
    KeyRow(value: 50, key: .increment, modifiers: [], step: 0, range: 0...100, expected: 51),
    KeyRow(value: 0.5, key: .increment, modifiers: [], step: 0, range: 0...1, expected: 0.51),
    KeyRow(value: 50, key: .increment, modifiers: [], step: 5, range: 0...100, expected: 55),
    KeyRow(value: 52, key: .increment, modifiers: [], step: 5, range: 0...100, expected: 55),
    KeyRow(value: 50, key: .increment, modifiers: .shift, step: 5, range: 0...100, expected: 100),
    KeyRow(value: 50, key: .increment, modifiers: .option, step: 5, range: 0...100, expected: 50.5),
    KeyRow(value: 400, key: .increment, modifiers: [], step: 1, range: 0...360, expected: 360),
    KeyRow(value: .nan, key: .increment, modifiers: [], step: 1, range: 0...360, expected: 0),
    KeyRow(value: 7, key: .decrement, modifiers: .option, step: 1, range: 0...10, expected: 6.9),
]

private let scrubbing = SuiteValueScrubbing()

@Test func theReferenceTableHasSixtyRows() {
    #expect(dragRows.count + keyRows.count == 60)
}

@Test func everyDragRowMatchesTheReference() {
    for (index, row) in dragRows.enumerated() {
        let spec = ScrubSpec(range: row.range, step: row.step)
        let got = scrubbing.dragged(from: row.start, by: row.points, modifiers: row.modifiers, spec: spec)
        #expect(got == row.expected, "drag row \(index + 1)")
    }
}

@Test func everyKeyRowMatchesTheReference() {
    for (index, row) in keyRows.enumerated() {
        let spec = ScrubSpec(range: row.range, step: row.step)
        let got = scrubbing.pressed(row.key, from: row.value, modifiers: row.modifiers, spec: spec, track: nil)
        #expect(got == row.expected, "key row \(index + 1)")
    }
}

@Test func aScrubTrackStepsThroughTheTrackAwarePress() {
    // A log track over 0.1...10 whose own step leaves the detent at 1 (#591).
    let track = ScrubTrack(
        positions: -1...1, step: 0.01, position: { log10($0) }, value: { pow(10, $0) },
        stepped: { position, delta in position + delta * 2 })
    let spec = ScrubSpec(range: 0.1...10, step: 0.01)
    let up = scrubbing.pressed(.increment, from: 1, modifiers: [], spec: spec, track: track)
    let expected = pow(10, ScrubValue.pressed(.increment, from: 0, on: track))
    #expect(up == expected)
    #expect(up > 1)
    let end = scrubbing.pressed(.end, from: 1, modifiers: [], spec: spec, track: track)
    #expect(end == 10)
}

@Test func aTrackWithNoOwnStepGivesThePlainPress() {
    let track = ScrubTrack(positions: 0...360, step: 1, position: { $0 }, value: { $0 })
    let spec = ScrubSpec(range: 0...360, step: 1)
    for row in keyRows where row.range == 0...360 && row.step == 1 && row.value.isFinite && row.value <= 360 {
        let got = scrubbing.pressed(row.key, from: row.value, modifiers: row.modifiers, spec: spec, track: track)
        #expect(got == row.expected)
    }
}
