// PresetGridTests.swift: how arrow keys move focus in a PresetGrid (its
// SuitePresetNavigating rule stops at the edges, where FakePresetNavigating
// wraps), that a toggle chip reports On and Off, that each option's
// identifier lands on its own button (#1148), and that a chip's state change
// records one `fade-start`/`fade-end` pair on series `chip` with the Reduce
// Motion switch off (about 0.14 s apart) and on (at once). macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

/// Six presets in two columns:  0 1 / 2 3 / 4 5.
@Test func arrowsMoveWithinTheGridAndStopAtItsEdges() {
    let rule = SuitePresetNavigating()
    func move(_ index: Int, _ arrow: GridArrow) -> Int? { rule.neighbor(of: index, arrow, count: 6, columns: 2) }
    #expect(move(0, .right) == 1 && move(1, .left) == 0)
    #expect(move(0, .down) == 2 && move(3, .up) == 1)
    #expect(move(1, .right) == nil && move(2, .left) == nil)
    #expect(move(0, .up) == nil && move(5, .down) == nil)
    #expect(rule.neighbor(of: 0, .right, count: 0, columns: 2) == nil)
    #expect(rule.neighbor(of: 7, .left, count: 6, columns: 2) == nil)
}

/// Seven presets in three columns:  0 1 2 / 3 4 5 / 6. The grid never wraps.
@Test func sevenPresetsInThreeColumnsStopAtEachEdge() {
    let rule = SuitePresetNavigating()
    func move(_ index: Int, _ arrow: GridArrow) -> Int? { rule.neighbor(of: index, arrow, count: 7, columns: 3) }
    #expect(move(2, .right) == nil)
    #expect(move(4, .down) == nil)
    #expect(move(1, .down) == 4)
    #expect(move(3, .down) == 6 && move(6, .right) == nil && move(6, .up) == 3)
    // The Fake wraps where the live rule stops, so a page built on it shows the difference.
    #expect(FakePresetNavigating().neighbor(of: 2, .right, count: 7, columns: 3) == 3)
}

@Test func arrowKeysMapToGridArrows() {
    #expect(PresetGrid<Int>.arrow(.leftArrow) == .left && PresetGrid<Int>.arrow(.rightArrow) == .right)
    #expect(PresetGrid<Int>.arrow(.upArrow) == .up && PresetGrid<Int>.arrow(.downArrow) == .down)
    #expect(PresetGrid<Int>.arrow(.return) == nil)
}

@Test func aToggleChipReportsOnAndOff() {
    #expect(ChipItem(id: 1, title: "Onion Skin", isOn: true).stateText == "On")
    #expect(ChipItem(id: 1, title: "Onion Skin", isOn: false).stateText == "Off")
}

/// Each identified option's button carries its own id; one without stays unidentified (#1148: an id on the grid
/// reached no button, so journeys could only find presets by title).
@MainActor @Test func eachOptionsIdentifierLandsOnItsOwnButton() {
    let app = NSApplication.shared
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let options = [
        InspectorOption(id: 1, title: "Square", identifier: "p.Square"),
        InspectorOption(id: 2, title: "Wide", identifier: "p.Wide"),
        InspectorOption(id: 3, title: "Custom"),
    ]
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 300, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = NSHostingView(rootView: PresetGrid(options: options, selected: 1, columns: 3) { _ in }.padding(20))
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    #expect(axButtons(in: window).map(\.id) == ["p.Square", "p.Wide", ""])
}

/// One chip turned on then off records two fade pairs on series `chip`: about
/// 0.14 s long with the switch off, and 0 long with it on.
@MainActor @Test(arguments: [false, true]) func aChipRecordsAFadePairPerChange(reduceMotion: Bool) {
    let marks = MarkLog()
    let holder = ChipHolder()
    let probe = ChipProbe(record: { marks.items.append($0) }, sample: { _ in })
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 200, height: 60), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = NSHostingView(
        rootView: ChipHost(holder: holder)
            .environment(\.chipProbe, probe)
            .environment(\.suiteReduceMotion, reduceMotion))
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    #expect(marks.items.isEmpty)
    for isOn in [true, false] {
        holder.isOn = isOn
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    }
    let fades = marks.items.filter { $0.series == ChipProbe.fadeSeries }
    #expect(fades.map(\.name) == ["fade-start", "fade-end", "fade-start", "fade-end"])
    for pair in stride(from: 0, to: fades.count - 1, by: 2) {
        let length = fades[pair + 1].time - fades[pair].time
        if reduceMotion { #expect(length < 0.05) } else { #expect(length > 0.09 && length < 0.4) }
    }
}

/// A press records one `press` sample, shown no earlier than it happened.
@MainActor @Test func aPressRecordsOnePressSample() async {
    let samples = SampleLog()
    let probe = ChipProbe(record: { _ in }, sample: { samples.items.append($0) })
    var pressed = 0
    ChipProbe.press(probe) { pressed += 1 }
    ChipProbe.press(nil) { pressed += 1 }
    #expect(pressed == 2)
    for _ in 0..<20 where samples.items.isEmpty { await Task.yield() }
    #expect(samples.items.count == 1)
    #expect(samples.items.allSatisfy { $0.series == ChipProbe.pressSeries && $0.shownAt >= $0.eventTime })
}

@MainActor private final class MarkLog { var items: [ProbeMark] = [] }
@MainActor private final class SampleLog { var items: [ProbeSample] = [] }

@MainActor @Observable private final class ChipHolder {
    var isOn = false
}

private struct ChipHost: View {
    let holder: ChipHolder
    var body: some View {
        ChipRow([ChipItem(id: 0, title: "Onion", isOn: holder.isOn)]) { _ in }.padding(20)
    }
}
