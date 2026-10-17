// SwitchMenuTests.swift: the six Window > Switch To items (blueprint 6.2):
// their order, digits, and when each is enabled or says why it isn't.
import SuiteModel
import Testing

@Suite struct SwitchMenuTests {
    @Test func sixItemsInOrderWithDigits0To5() {
        let items = SwitchMenu.items(current: .launcher, states: [:])
        #expect(items.map(\.app) == [.launcher, .flare, .design, .photo, .library, .halo])
        #expect(items.map(\.digit) == [0, 1, 2, 3, 4, 5])
        #expect(items.first?.title == "Show AfterGlow Window")
    }

    @Test func theCurrentAppWithAWindowIsDisabledAndSaysSo() {
        let items = SwitchMenu.items(current: .flare, states: [.flare: .running(windows: 1)])
        let flare = items.first { $0.app == .flare }
        #expect(flare?.enabled == false)
        #expect(flare?.reason == "You're in Flare.")
    }

    @Test func theCurrentAppWithNoWindowReadsShowAndIsEnabled() {
        let items = SwitchMenu.items(current: .flare, states: [.flare: .running(windows: 0)])
        let flare = items.first { $0.app == .flare }
        #expect(flare?.title == "Show Flare Window")
        #expect(flare?.enabled == true)
        #expect(flare?.reason == nil)
    }

    @Test func aMissingAppIsDisabledWithItsSentence() {
        let items = SwitchMenu.items(current: .flare, states: [.halo: .missing])
        let halo = items.first { $0.app == .halo }
        #expect(halo?.enabled == false)
        #expect(halo?.reason == SuiteError.appMissing(.halo).message)
    }

    @Test func otherAppsAreEnabledAndNamedByTheirOwnName() {
        let items = SwitchMenu.items(current: .flare, states: [.design: .running(windows: 3)])
        let design = items.first { $0.app == .design }
        #expect(design?.title == "Design")
        #expect(design?.enabled == true)
    }
}
