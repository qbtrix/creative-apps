// AfterGlowHomeSidebarTests.swift: the home sidebar's app section is titled
// for what its rows do, filter the recents, not launch the apps (#1869).
// The afterglow-home-* snapshots show the header. macOS only.
import SuiteModel
import SuiteUI
import Testing

@testable import AfterGlowApp

@MainActor
@Suite struct AfterGlowHomeSidebarTests {
    @Test func appSectionSaysItsRowsFilterRecents() {
        let apps = HomeSidebarRows.sections.first { $0.id == "apps" }
        #expect(apps?.title == "Recents by App")
        #expect(apps?.title.localizedCaseInsensitiveContains("recent") == true)
        #expect(apps?.items.map(\.title) == SuiteApp.apps.map(\.displayName))
    }
}
