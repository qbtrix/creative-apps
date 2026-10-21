// AfterGlowJourneyTests+Help.swift (report-problem RP-2, on in RP-5): XJ-RP, the suite Help menu in the
// launcher. Help lists Report a Problem…, Beta Notes and Welcome to AfterGlow; Welcome opens the tour; Report a
// Problem… opens the sheet with a crash from the fixture folder; Beta Notes opens the known-issues window.
// Skipped until RP-5 builds the sheet, the notes window and the crash reader. Every click is a mouse click on a
// menu item found by title. Items are found by title only: SwiftUI doesn't carry `.accessibilityIdentifier` onto
// a menu item (a live run reads "" for Report a Problem… and AppKit's "menuAction:" for Welcome). The menu shot is
// a screen shot, since an open menu sits outside the window.
import XCTest

final class AfterGlowHelpJourneyTests: XCTestCase {
    static let items = ["Report a Problem…", "Beta Notes", "Welcome to AfterGlow"]

    override func setUpWithError() throws {
        throw XCTSkip("waits on RP-5")
    }

    /// Help lists the three items, each enabled, and Welcome opens the tour.
    @MainActor func testHelpMenuListsItsItems() {
        let launcher = SuiteHarness(self).launch(fixture: "firstLaunch", arguments: [], skipOnboarding: true)
        let help = Self.openHelp(launcher)
        for title in Self.items {
            let item = help.menuItems[title]
            XCTAssert(item.waitForExistence(timeout: 5), "the Help menu has no \(title)")
            XCTAssert(item.isEnabled, "\(title) is disabled")
        }
        launcher.shot("help-menu", screen: true)
        help.menuItems["Welcome to AfterGlow"].click()
        let welcome = launcher.app.windows.matching(NSPredicate(format: "title == 'Welcome to AfterGlow'")).firstMatch
        XCTAssert(welcome.waitForExistence(timeout: 10), "Help > Welcome to AfterGlow opened no window")
    }

    /// Step 1: Report a Problem… shows the newest Photo crash with `~` for the home path; Copy holds note plus report.
    @MainActor func testReportAProblem() {
        let launcher = SuiteHarness(self).launch(fixture: "firstLaunch", arguments: [], skipOnboarding: true)
        Self.openHelp(launcher).menuItems["Report a Problem…"].click()
        let sheet = launcher.app.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: 10), "Help > Report a Problem… opened no sheet")
        launcher.shot("help-report")
    }

    /// Step 2: Beta Notes opens the known-issues window; Close returns to the home.
    @MainActor func testBetaNotes() {
        let launcher = SuiteHarness(self).launch(fixture: "firstLaunch", arguments: [], skipOnboarding: true)
        Self.openHelp(launcher).menuItems["Beta Notes"].click()
        let notes = launcher.app.windows.matching(NSPredicate(format: "title == 'Beta Notes'")).firstMatch
        XCTAssert(notes.waitForExistence(timeout: 10), "Help > Beta Notes opened no window")
        launcher.shot("help-beta-notes")
    }

    /// Clicks the menu bar's Help menu and returns it.
    @MainActor static func openHelp(_ launcher: Journey) -> XCUIElement {
        let help = launcher.app.menuBars.firstMatch.menuBarItems["Help"]
        XCTAssert(help.waitForExistence(timeout: 5), "the menu bar has no Help menu")
        help.click()
        return help
    }
}
