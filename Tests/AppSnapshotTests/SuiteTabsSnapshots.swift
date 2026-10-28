// SuiteTabsSnapshots.swift: SegmentedTabs as a capsule on the editor panel,
// in three states: Layers selected, the capsule hovered, and disabled with
// its reason. Writes suiteui-tabs-light.png and suiteui-tabs-dark.png, and
// checks the sheet against Golden/chrome/tabs-<appearance>.png in the four
// appearances (QB-V5; a known issue until EC-13 commits the baselines).
// `segmentsFillTheCapsule` hosts the switch in a real NSHostingView and checks
// the system segmented control spans the capsule, not just its labels.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteTabsSnapshots {
    @Test func tabStates() throws {
        try snapshot(TabsSheet(), name: "suiteui-tabs-light", scheme: .light)
        try snapshot(TabsSheet(), name: "suiteui-tabs-dark", scheme: .dark)
    }

    /// The segments fill the capsule's width (docs/design.md, Tabs), at the
    /// inspector's narrowest and widest and in the editor panel: the Library
    /// finish pass found a label-wide control centered in a wide capsule.
    @Test func segmentsFillTheCapsule() throws {
        let tabs = [InspectorOption(id: 0, title: "Info"), InspectorOption(id: 1, title: "Develop")]
        for width in [SuiteSize.inspectorWidth.min, SuiteSize.inspectorWidth.max, SuiteSize.editorPanelWidth] {
            let host = NSHostingView(rootView: SegmentedTabs("Tabs", tabs: tabs, selection: 0) { _ in }
                .frame(width: width))
            host.frame = CGRect(x: 0, y: 0, width: width, height: 80)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            host.layoutSubtreeIfNeeded()
            let control = try #require(Self.segmented(in: host), "no segmented control at \(width)")
            // The capsule is the width less SuiteSpacing.s outside and SuiteSpacing.xxs inside, each side.
            let inner = width - 2 * (SuiteSpacing.s + SuiteSpacing.xxs)
            #expect(control.frame.width >= inner - 2, "segments \(control.frame.width) pt in a \(inner) pt capsule")
        }
    }

    private static func segmented(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        return view.subviews.lazy.compactMap { segmented(in: $0) }.first
    }

    @Test func tabsGoldens() {
        let size = CGSize(width: SuiteSize.editorPanelWidth + 2 * SuiteSpacing.xxl, height: 220)
        for appearance in SnapshotAppearance.allCases {
            assertGolden(TabsSheet(), size: size, name: "tabs", area: "chrome", appearance: appearance)
        }
    }
}

private struct TabsSheet: View {
    private let tabs = [InspectorOption(id: 0, title: "Adjust"), InspectorOption(id: 1, title: "Layers")]

    var body: some View {
        VStack(spacing: 0) {
            SegmentedTabs("Selected", tabs: tabs, selection: 1, id: "suite.tabs.selected") { _ in }
                .environment(\.tabsHover, false)
            SegmentedTabs("Hovered", tabs: tabs, selection: 0, id: "suite.tabs.hovered") { _ in }
                .environment(\.tabsHover, true)
            SegmentedTabs(
                "Disabled", tabs: tabs, selection: 0, id: "suite.tabs.disabled",
                unavailableHelp: "Open a photo to adjust it.") { _ in }
        }
        .frame(width: SuiteSize.editorPanelWidth)
        .background(SuiteColor.panel)
        .environment(\.suiteReduceMotion, true)
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
