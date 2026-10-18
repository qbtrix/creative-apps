// SuiteTabsSnapshots.swift: SegmentedTabs as a capsule on the editor panel,
// in three states: Layers selected, the capsule hovered, and disabled with
// its reason. Writes suiteui-tabs-light.png and suiteui-tabs-dark.png, and
// checks the sheet against Golden/chrome/tabs-<appearance>.png in the four
// appearances (QB-V5; a known issue until EC-13 commits the baselines).
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteTabsSnapshots {
    @Test func tabStates() throws {
        try snapshot(TabsSheet(), name: "suiteui-tabs-light", scheme: .light)
        try snapshot(TabsSheet(), name: "suiteui-tabs-dark", scheme: .dark)
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
