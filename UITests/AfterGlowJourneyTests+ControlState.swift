// AfterGlowJourneyTests+ControlState.swift: toggles report their state in
// `suite.controls` (command-state packet, CS-1 wrote it, CS-15 runs it, XJ-CS).
// `testTogglesReportState`: the launcher on `weekOfWork` (the class's last
// test, so its teardown attaches the `afterglow` counts), then Library, the
// helper inside AfterGlow.app, on its `shoot` fixture with the probes on. A
// photo double-clicked into the loupe, the inspector's Develop tab, Show
// Original pressed: `suite.controls` lists `library.develop.original` with
// `selected: true`, and with `selected: false` after a second press. The
// harness's teardown ends both processes.
import XCTest

extension AfterGlowJourneyTests {
    static let originalID = "library.develop.original"

    /// CS-15: Show Original reports on, then off, in `suite.controls`.
    @MainActor func testTogglesReportState() throws {
        let suite = SuiteHarness(self)
        let home = suite.launch(fixture: "weekOfWork", arguments: ["-SuitePerfProbe", "YES"])
        XCTAssert(home.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window")
        let library = Journey(
            bundlePath: SuiteHarness.bundle.appending(path: SuiteApp.library.bundlePath).path,
            bundleID: SuiteApp.library.bundleID, auditKey: SuiteHarness.auditKey(.library), self)
        library.app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-LibraryFixture", "shoot", "-SuitePerfProbe", "YES"]
        library.app.launch()
        library.app.activate()
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "Library opened no window")

        // A photo in the loupe, the Develop tab.
        let cell = library.app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'library.grid.cell.'")).firstMatch
        XCTAssert(cell.waitForExistence(timeout: 60), "the shoot fixture shows no grid cell")
        cell.doubleClick()
        XCTAssert(library.element("library.loupe").waitForExistence(timeout: 10), "double-click didn't open the loupe")
        let tab = library.element("suite.inspector").descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Develop'")).firstMatch
        XCTAssert(tab.waitForExistence(timeout: 5), "the inspector has no Develop tab")
        tab.click()
        let button = library.element(Self.originalID)
        XCTAssert(button.waitForExistence(timeout: 5), "no Show Original (\(Self.originalID))")
        XCTAssertEqual(Self.original(library)?.selected, false, "Show Original reads \(Self.describe(library)) before a press")

        // Press: on. Press again: off.
        button.click()
        XCTAssert(Self.waitForOriginal(true, library), "after a press Show Original reads \(Self.describe(library)), not selected")
        library.shot("control-state-original-on")
        button.click()
        XCTAssert(Self.waitForOriginal(false, library), "after a second press Show Original reads \(Self.describe(library))")
        library.shot("control-state-original-off")
    }

    /// Show Original's `suite.controls` entry in Library's window, nil while it lists none.
    @MainActor static func original(_ library: Journey) -> ControlEntry? {
        library.controls()?.controls.first { $0.id == originalID }
    }

    /// The entry as words, for a failure message.
    @MainActor static func describe(_ library: Journey) -> String {
        original(library).map { "enabled \($0.enabled), selected \($0.selected.map { "\($0)" } ?? "absent")" } ?? "no entry"
    }

    /// Waits up to five seconds for Show Original's entry to report `selected`.
    @MainActor static func waitForOriginal(_ selected: Bool, _ library: Journey) -> Bool {
        let deadline = Date(timeIntervalSinceNow: 5)
        while Date() < deadline {
            if original(library)?.selected == selected { return true }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
        }
        return original(library)?.selected == selected
    }
}
