// SliderBarTests.swift: the number rules of the bar slider (InspectorSliderRow)
// and ScrubField: what the arrows, Shift, Option, Home and End give, how far the
// fill reaches, the value text with its unit and the words VoiceOver reads, and
// a non-linear track with a detent, and that a keyed row keeps its size. The
// bar reads its value to VoiceOver: its slider's value is the row's text over
// any track, a VoiceOver step lands where the arrow key does, and its drags
// and key steps carry series `bar-slider` and `slider-key` (IC-7, #262). macOS.
import AppKit
import SwiftUI
@testable import SuiteUI
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

/// Photo's gamma shape: log10 positions over 0.1...10, a detent at 1, and a
/// track that owns its step (ten track steps a press).
private let gamma = ScrubTrack(
    positions: -1...1, step: 0.01, position: { log10($0) }, value: { abs($0) <= 0.02 ? 1 : pow(10, $0) },
    stepped: { position, delta in position + delta * 10 })

/// VoiceOver's increment and decrement give exactly the unmodified arrow
/// key's position, on a plain track and on one that owns its step.
@MainActor @Test func voiceOverStepsWhereTheArrowKeysDo() {
    let plain = ScrubTrack(positions: -180...180, step: 1, position: { $0 }, value: { $0 })
    for (track, from) in [(plain, 45.0), (plain, 180), (gamma, 0), (gamma, -1)] {
        let up = ScrubAccessibility.stepped(.increment, from: from, on: track)
        let down = ScrubAccessibility.stepped(.decrement, from: from, on: track)
        #expect(up == ScrubValue.pressed(.increment, from: from, on: track))
        #expect(down == ScrubValue.pressed(.decrement, from: from, on: track))
    }
    #expect(ScrubAccessibility.stepped(.increment, from: 45, on: plain) == 46)
    #expect(ScrubAccessibility.stepped(.decrement, from: 180, on: plain) == 179)
}

/// The bar's drag reports `bar-slider`, the exact field's `exact-field`, and
/// a bar's key step `slider-key`: the series SP1 and SP6 read.
@Test func barDragsAndKeyStepsCarryTheirSeries() {
    #expect(ScrubProbe.dragSeries(isBar: true) == "bar-slider")
    #expect(ScrubProbe.dragSeries(isBar: false) == "exact-field")
    let key = ScrubProbe.sample(ScrubProbe.keySeries, eventTime: 2, shownAt: 2.01)
    #expect(key == ProbeSample(series: "slider-key", eventTime: 2, shownAt: 2.01))
    var probe = FakeFrameProbe()
    probe.record(key)
    probe.record(ScrubProbe.sample(ScrubProbe.dragSeries(isBar: true), eventTime: 1, shownAt: 1.01))
    #expect(probe.summary(of: "slider-key", refreshInterval: 1.0 / 60).count == 1)
    #expect(probe.summary(of: "bar-slider", refreshInterval: 1.0 / 60).count == 1)
}

/// On the gamma track the slider reads the value's text (at the detent, not
/// its log position 0), and one increment through the accessibility tree
/// sends the value the arrow key gives, with one end.
@MainActor @Test func theBarsSliderReadsTheRowsTextOnATrack() throws {
    let log = SentLog()
    let row = InspectorSliderRow(
        "Gamma", value: 1, in: 0.1...10, decimals: 2, track: gamma,
        onChange: { log.values.append($0) }, onEnd: { log.ends += 1 })
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 320, height: 80), styleMask: [.titled], backing: .buffered, defer: false)
    defer { window.orderOut(nil) }
    NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXManualAccessibility"))
    window.contentView = NSHostingView(rootView: row.frame(width: SuiteSize.editorPanelWidth))
    window.orderFrontRegardless()
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    let slider = try #require(firstSlider(under: window), "the bar is no slider")
    let reading = slider.value(forKey: "accessibilityValueDescription") as? String
    #expect(reading == NumericInput.spoken(1, decimals: 2))
    let stepped = (slider as AnyObject).accessibilityPerformIncrement?()
    #expect(stepped == true)
    let expected = gamma.value(ScrubValue.pressed(.increment, from: gamma.position(1), on: gamma))
    #expect(log.values == [expected] && log.ends == 1)
}

@MainActor private final class SentLog {
    var values: [Double] = []
    var ends = 0
}

/// The first slider in `element`'s accessibility subtree, depth first.
@MainActor private func firstSlider(under element: Any) -> NSObject? {
    let node = element as AnyObject
    if node.accessibilityRole?() == .slider { return node as? NSObject }
    let children = (node.accessibilityChildren?() ?? nil) ?? []
    return children.lazy.compactMap { firstSlider(under: $0) }.first
}
