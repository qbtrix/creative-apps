// SuiteTabsSnapshots.swift: SegmentedTabs as the capsule tab switch at the
// top of the editor's right panel: the selected tab at rest, hovered, and
// disabled with its reason. Writes suiteui-tabs-light.png and
// suiteui-tabs-dark.png, and checks the three states against
// Golden/chrome/tabs-<appearance>.png in the four appearances (EC-13 commits
// the baselines). Also proves the switch is still a system Picker underneath
// and that its suite.controls reason is its tooltip. macOS only.
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteTabsSnapshots {
    @Test func tabs() throws {
        try snapshot(TabsSheet(), name: "suiteui-tabs-light", scheme: .light)
        try snapshot(TabsSheet(), name: "suiteui-tabs-dark", scheme: .dark)
    }

    @Test func tabsGolden() {
        let size = CGSize(width: SuiteSize.editorPanelWidth, height: 180)
        for appearance in SnapshotAppearance.allCases {
            assertGolden(TabsStates(), size: size, name: "tabs", area: "chrome", appearance: appearance)
        }
    }

    /// The capsule is drawn around the system control, never instead of it.
    @Test func stillBuildsAPicker() {
        let tabs = SegmentedTabs("Panel", tabs: TabsStates.options, selection: 0) { _ in }
        #expect(String(reflecting: type(of: tabs.body)).contains("SwiftUI.Picker<"))
    }

    @Test func disabledReasonIsItsTooltip() {
        let reason = "Layers need an open document."
        let off = SegmentedTabs(
            "Panel", tabs: TabsStates.options, selection: 0, identifier: "suite.tabs", unavailableHelp: reason) { _ in }
        #expect(off.controlEntry == ControlEntry(id: "suite.tabs", enabled: false, reason: reason))
        let on = SegmentedTabs("Panel", tabs: TabsStates.options, selection: 1, identifier: "suite.tabs") { _ in }
        #expect(on.controlEntry == ControlEntry(id: "suite.tabs", enabled: true, reason: nil))
        #expect(SegmentedTabs("Panel", tabs: TabsStates.options, selection: 0) { _ in }.controlEntry == nil)
    }
}

/// Selected at rest, hovered, and disabled, stacked on the editor panel.
private struct TabsStates: View {
    static let options = [InspectorOption(id: 0, title: "Adjust"), InspectorOption(id: 1, title: "Layers")]

    var body: some View {
        VStack(spacing: 0) {
            SegmentedTabs("Panel", tabs: Self.options, selection: 0) { _ in }
            SegmentedTabs("Panel", tabs: Self.options, selection: 1) { _ in }.showingHover()
            SegmentedTabs(
                "Panel", tabs: Self.options, selection: 0,
                unavailableHelp: "Layers need an open document.") { _ in }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(SuiteColor.panel)
    }
}

private struct TabsSheet: View {
    var body: some View {
        TabsStates()
            .frame(width: SuiteSize.editorPanelWidth)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(SuiteColor.canvasSurround)
    }
}
