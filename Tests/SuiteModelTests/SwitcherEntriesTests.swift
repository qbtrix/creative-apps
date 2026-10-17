// SwitcherEntriesTests.swift: the switcher's rows agree with Window > Switch To
// (SW-3d; blueprint 6.2): one row per menu item, in order, with the same
// enablement and reason, and the shortcut text each row shows.
import SuiteModel
import Testing

@Suite struct SwitcherEntriesTests {
    /// Run-state mixes the switcher and the menu must agree on.
    private let mixes: [[SuiteApp: AppRunState]] = [
        [:],
        [.flare: .running(windows: 1), .halo: .missing],
        [.flare: .running(windows: 0), .design: .running(windows: 3), .photo: .notRunning],
        [.launcher: .running(windows: 1), .library: .missing, .halo: .running(windows: 2)],
    ]

    @Test func oneRowPerMenuItemInTheSameOrderWithTheSameEnablementAndReason() {
        for current in SuiteApp.allCases {
            for states in mixes {
                let items = SwitchMenu.items(current: current, states: states)
                let rows = SwitcherEntries.entries(current: current, states: states)
                #expect(rows.map(\.app) == items.map(\.app))
                #expect(rows.map(\.reason) == items.map(\.reason))
                #expect(rows.map { $0.reason == nil } == items.map(\.enabled))
            }
        }
    }

    @Test func shortcutsAreControlCommandDigitsZeroToFive() {
        let rows = SwitcherEntries.entries(current: .launcher, states: [:])
        #expect(rows.map(\.shortcut) == ["⌃⌘0", "⌃⌘1", "⌃⌘2", "⌃⌘3", "⌃⌘4", "⌃⌘5"])
    }

    @Test func aMissingAppsRowCarriesTheMissingSentence() {
        let halo = SwitcherEntries.entries(current: .flare, states: [.halo: .missing]).first { $0.app == .halo }
        #expect(halo?.reason == SuiteError.appMissing(.halo).message)
    }

    @Test func theCurrentAppWithAWindowSaysYoureIn() {
        let flare = SwitcherEntries.entries(current: .flare, states: [.flare: .running(windows: 1)]).first { $0.app == .flare }
        #expect(flare?.reason == "You're in Flare.")
    }

    @Test func homeIsTitledHomeAndTheAppsByTheirNames() {
        let rows = SwitcherEntries.entries(current: .launcher, states: [:])
        #expect(rows.map(\.title) == ["Home", "Flare", "Design", "Photo", "Library", "Halo"])
        #expect(rows.first?.systemImage == "house")
    }
}
