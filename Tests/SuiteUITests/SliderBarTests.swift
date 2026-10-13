// SliderBarTests.swift: the number rules of the bar slider (InspectorSliderRow)
// and ScrubField: what the arrows, Shift, Option, Home and End give, how far the
// fill reaches, the value text with its unit and the words VoiceOver reads, and
// a non-linear track with a detent, and that a keyed row keeps its size. macOS.
import SwiftUI
import SuiteUI
import Testing

@Test func arrowsStepWithShiftCoarseAndOptionFine() {
    #expect(ScrubValue.pressed(.increment, from: 45, step: 1, in: -180...180) == 46)
    #expect(ScrubValue.pressed(.decrement, from: 45, step: 1, in: -180...180) == 44)
    #expect(ScrubValue.pressed(.increment, from: 45, step: 1, shift: true, in: -180...180) == 55)
    #expect(ScrubValue.pressed(.decrement, from: 0.5, step: 0.1, option: true, in: -5...5) == 0.49)
    #expect(ScrubValue.pressed(.increment, from: 179.5, step: 1, shift: true, in: -180...180) == 180)
    #expect(ScrubValue.pressed(.increment, from: 40, step: .nan, in: 0...100) == 40)
}

@Test func homeAndEndJumpToTheEnds() {
    #expect(ScrubValue.pressed(.home, from: 12, step: 1, in: 0...100) == 0)
    #expect(ScrubValue.pressed(.end, from: 12, step: 1, shift: true, in: 0...100) == 100)
}

@Test func fillReachesTheValueAndStaysInside() {
    #expect(ScrubValue.fraction(0.5, in: -1...2) == 0.5)
    #expect(ScrubValue.fraction(-4, in: 0...1) == 0)
    #expect(ScrubValue.fraction(9, in: 0...1) == 1)
    #expect(ScrubValue.fraction(.nan, in: 0...1) == 0)
    #expect(ScrubValue.fraction(1, in: 1...1) == 0)
}

@Test func valueTextShowsTheFieldsPrecisionWithItsUnit() {
    #expect(NumericInput.text(45, decimals: 0, unit: "°") == "45°")
    #expect(NumericInput.text(100, decimals: 0, unit: "%") == "100%")
    #expect(NumericInput.text(1, decimals: 2, unit: "×") == "1.00×")
    #expect(NumericInput.text(0, decimals: 1, unit: "pt") == "0.0 pt")
    #expect(NumericInput.text(1.25, decimals: 1, unit: "EV") == "1.3 EV")
    #expect(NumericInput.text(-0.04, decimals: 1) == "0.0")
    #expect(NumericInput.text(0.998, decimals: 3) == "0.998")
    #expect(NumericInput.text(12, decimals: 0) == "12")
    #expect(NumericInput.text(.infinity, decimals: 2, unit: "px") == "inf px")
}

@Test func voiceOverReadsTheUnitAsWords() {
    #expect(NumericInput.spoken(45, decimals: 0, unit: "°") == "45 degrees")
    #expect(NumericInput.spoken(1, decimals: 0, unit: "px") == "1 pixel")
    #expect(NumericInput.spoken(50, decimals: 0, unit: "%") == "50 percent")
    #expect(NumericInput.spoken(1.5, decimals: 1, unit: "EV") == "1.5 EV")
    #expect(NumericInput.spoken(0.25) == "0.25")
}

/// A log10 track over 0.1...10 with a detent at 1, the shape Photo's gamma uses:
/// stepping from the middle lands back on exactly 1.
@Test func aTrackStepsInPositionsAndSnapsThroughItsValue() {
    let track = ScrubTrack(
        positions: -1...1, step: 0.01, position: { log10($0) }, value: { abs($0) <= 0.02 ? 1 : pow(10, $0) })
    let up = ScrubValue.pressed(.increment, from: track.position(1), step: track.step, in: track.positions)
    #expect(track.value(up) == 1)
    let far = ScrubValue.dragged(from: track.position(1), by: 100, step: track.step, in: track.positions)
    #expect(track.value(far) == 10)
    #expect(ScrubValue.fraction(track.position(1), in: track.positions) == 0.5)
}

/// One 28 pt row whatever it shows, so a row never resizes while the timeline scrubs.
@MainActor @Test func keyedOrMixedRowKeepsItsSize() {
    func size(keyed: Bool = false, mixed: Bool = false) -> CGSize {
        let row = InspectorSliderRow("Rotation", value: 45, in: -180...180, unit: "°", decimals: 0, keyed: keyed, mixed: mixed) { _ in }
        return NSHostingView(rootView: row.frame(width: SuiteSize.editorPanelWidth)).fittingSize
    }
    #expect(size().height == SuiteSize.studioRow)
    #expect(size(keyed: true) == size())
    #expect(size(mixed: true) == size())
}
