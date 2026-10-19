// SegmentedTabsTests.swift: that SegmentedTabs is still a system Picker
// underneath its capsule (EC-7), that its `suite.controls` entry's reason is
// its tooltip while it can't act, and that a selection change records one
// `fade-start`/`fade-end` pair on series `tabs` with the Reduce Motion switch
// off (about 0.14 s apart) and on (at once), that ← and → step to the
// neighbouring tab and stop at either end, and that each segment carries an
// identifier under the switch's `id` and is listed in `suite.controls`
// under it. macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

private let panelTabs = [InspectorOption(id: 0, title: "Adjust"), InspectorOption(id: 1, title: "Layers")]

/// Looks for the AppKit control a segmented Picker hosts, not at `picker`'s type: naming that
/// type makes a release test build reference SwiftUI's `tag(_:includeOptional:)` opaque type,
/// which the macOS 26 runtime doesn't export (#2714).
@MainActor @Test func theTabsStillBuildASystemPicker() {
    let host = NSHostingView(rootView: SegmentedTabs("Panel", tabs: panelTabs, selection: 0) { _ in })
    host.frame = CGRect(x: 0, y: 0, width: 280, height: 60)
    host.layoutSubtreeIfNeeded()
    func segmented(in view: NSView) -> [NSSegmentedControl] {
        (view as? NSSegmentedControl).map { [$0] } ?? view.subviews.flatMap(segmented)
    }
    let controls = segmented(in: host)
    #expect(controls.map(\.segmentCount) == [panelTabs.count], "SegmentedTabs hosts no system segmented control")
}

@Test func theArrowsStepToTheNeighbouringTab() {
    let ids = [0, 1, 2]
    #expect(SegmentedTabs<Int>.step(ids, from: 1, by: -1) == 0)
    #expect(SegmentedTabs<Int>.step(ids, from: 1, by: 1) == 2)
    #expect(SegmentedTabs<Int>.step(ids, from: 0, by: -1) == nil)
    #expect(SegmentedTabs<Int>.step(ids, from: 2, by: 1) == nil)
    #expect(SegmentedTabs<Int>.step(ids, from: 7, by: 1) == nil)
}

@Test func eachSegmentCarriesAnIdentifier() {
    #expect(SegmentedTabs<Int>.segmentID(panelTabs[1], in: "suite.tabs") == "suite.tabs.1")
    #expect(SegmentedTabs<Int>.segmentID(panelTabs[1], in: nil) == nil)
    let own = InspectorOption(id: 0, title: "Adjust", identifier: "photo.tab.adjust")
    #expect(SegmentedTabs<Int>.segmentID(own, in: "suite.tabs") == "photo.tab.adjust")
}

@Test func eachIdentifiedSegmentIsListed() {
    let on = SegmentedTabs<Int>.segmentEntries(panelTabs, in: "suite.tabs", enabled: true, reason: "Panel")
    #expect(on == [
        ControlEntry(id: "suite.tabs.0", enabled: true, reason: nil),
        ControlEntry(id: "suite.tabs.1", enabled: true, reason: nil),
    ])
    let off = SegmentedTabs<Int>.segmentEntries(panelTabs, in: "suite.tabs", enabled: false, reason: "Why")
    #expect(off.map(\.reason) == ["Why", "Why"])
    #expect(SegmentedTabs<Int>.segmentEntries(panelTabs, in: nil, enabled: true, reason: nil).isEmpty)
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
