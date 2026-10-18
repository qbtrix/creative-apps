// SegmentedTabsTests.swift: that SegmentedTabs is still a system Picker
// underneath its capsule (EC-7), that its `suite.controls` entry's reason is
// its tooltip while it can't act, and that a selection change records one
// `fade-start`/`fade-end` pair on series `tabs` with the Reduce Motion switch
// off (about 0.14 s apart) and on (at once). macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

private let panelTabs = [InspectorOption(id: 0, title: "Adjust"), InspectorOption(id: 1, title: "Layers")]

@MainActor @Test func theTabsStillBuildASystemPicker() {
    let tabs = SegmentedTabs("Panel", tabs: panelTabs, selection: 0) { _ in }
    let name = String(describing: type(of: tabs.picker))
    #expect(name.hasPrefix("Picker<"), "SegmentedTabs draws \(name), not a Picker")
}

@Test func theEntrysReasonEqualsItsHelp() {
    let why = "Open a photo to adjust it."
    let off = SegmentedTabs<Int>.entry("Panel", id: "suite.tabs", enabled: false, unavailable: why)
    #expect(off == ControlEntry(id: "suite.tabs", enabled: false, reason: SegmentedTabs<Int>.help("Panel", unavailable: why)))
    #expect(off.reason == why)
    let on = SegmentedTabs<Int>.entry("Panel", id: "suite.tabs", enabled: true)
    #expect(on == ControlEntry(id: "suite.tabs", enabled: true, reason: nil))
    #expect(SegmentedTabs<Int>.help("Panel") == "Panel")
    let bare = SegmentedTabs<Int>.entry("Panel", id: "suite.tabs", enabled: false)
    #expect(bare.reason == SegmentedTabs<Int>.help("Panel"))
}

/// Switching to Layers and back records two fade pairs on series `tabs`:
/// about 0.14 s long with the switch off, and 0 long with it on.
@MainActor @Test(arguments: [false, true]) func aTabChangeRecordsAFadePair(reduceMotion: Bool) {
    let marks = TabsMarkLog()
    let holder = TabsHolder()
    let probe = TabsProbe(record: { marks.items.append($0) })
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 280, height: 60), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = NSHostingView(
        rootView: TabsHost(holder: holder)
            .environment(\.tabsProbe, probe)
            .environment(\.suiteReduceMotion, reduceMotion))
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    #expect(marks.items.isEmpty)
    for tab in [1, 0] {
        holder.selection = tab
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    }
    let fades = marks.items.filter { $0.series == TabsProbe.fadeSeries }
    #expect(fades.map(\.name) == ["fade-start", "fade-end", "fade-start", "fade-end"])
    for pair in stride(from: 0, to: fades.count - 1, by: 2) {
        let length = fades[pair + 1].time - fades[pair].time
        if reduceMotion { #expect(length < 0.05) } else { #expect(length > 0.09 && length < 0.4) }
    }
}

@MainActor private final class TabsMarkLog { var items: [ProbeMark] = [] }

@MainActor @Observable private final class TabsHolder {
    var selection = 0
}

private struct TabsHost: View {
    let holder: TabsHolder
    var body: some View {
        SegmentedTabs("Panel", tabs: panelTabs, selection: holder.selection) { _ in }
    }
}
