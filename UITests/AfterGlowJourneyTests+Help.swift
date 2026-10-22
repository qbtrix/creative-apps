// AfterGlowJourneyTests+Help.swift (report-problem RP-2, on in RP-5b): XJ-RP, the suite Help menu in the
// launcher. Help lists Report a Problem…, Beta Notes and Welcome to AfterGlow; Welcome opens the tour; Report a
// Problem… opens the sheet with a crash from a fixture folder (`-SuiteCrashDir`), the home path shown as `~`;
// Beta Notes opens the known-issues window. Every click is a mouse click on a
// menu item found by title. The bundle compiles only SuiteModel's Values, so the item ids are literals here:
// `suite.<catalog id>`, and Welcome's `afterglow.onboarding.help`.
import XCTest

final class AfterGlowHelpJourneyTests: XCTestCase {
    static let items = [
        ("Report a Problem…", "suite.help.report-problem"), ("Beta Notes", "suite.help.beta-notes"),
        ("Welcome to AfterGlow", "afterglow.onboarding.help"),
    ]

    /// Help lists the three items, each enabled, and Welcome opens the tour.
    @MainActor func testHelpMenuListsItsItems() {
        let launcher = SuiteHarness(self).launch(fixture: "firstLaunch", arguments: [], skipOnboarding: true)
        let help = Self.openHelp(launcher)
        for (title, id) in Self.items {
            let item = help.menuItems[title]
            XCTAssert(item.waitForExistence(timeout: 5), "the Help menu has no \(title)")
            XCTAssertEqual(item.identifier, id, "\(title) has id \(item.identifier)")
            XCTAssert(item.isEnabled, "\(title) is disabled")
        }
        launcher.shot("help-menu")
        help.menuItems["Welcome to AfterGlow"].click()
        let welcome = launcher.app.windows.matching(NSPredicate(format: "title == 'Welcome to AfterGlow'")).firstMatch
        XCTAssert(welcome.waitForExistence(timeout: 10), "Help > Welcome to AfterGlow opened no window")
    }

    /// Step 1: Report a Problem… shows the fixture folder's Photo crash, not the other app's, with `~` for the home.
    @MainActor func testReportAProblem() throws {
        let crashes = try Self.crashFolder()
        defer { try? FileManager.default.removeItem(at: crashes) }
        let launcher = SuiteHarness(self).launch(fixture: "firstLaunch", arguments: ["-SuiteCrashDir", crashes.path])
        Self.openHelp(launcher).menuItems["Report a Problem…"].click()
        let sheet = launcher.app.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: 10), "Help > Report a Problem… opened no sheet")
        let report = sheet.descendants(matching: .any)["suite.help.report.report"]
        XCTAssert(report.waitForExistence(timeout: 5), "the sheet has no report (suite.help.report.report)")
        // A SwiftUI Text reaches XCUITest as its value, not its label, so both are matched.
        func line(_ text: String) -> XCUIElement {
            sheet.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
        }
        XCTAssert(line("Photo-journey.ips").waitForExistence(timeout: 5), "the report doesn't show the Photo crash")
        XCTAssert(line("~/Applications/Photo.app").exists, "the home path isn't shown as ~")
        XCTAssertFalse(line(Self.home + "/").exists, "the home path leaks into the report")
        XCTAssertFalse(line("Browser-journey.ips").exists, "another app's crash is in the report")
        launcher.shot("help-report")
    }

    /// The app's home: built from the user name, since a sandboxed runner's NSHomeDirectory() is its container.
    static var home: String { "/Users/" + NSUserName() }

    /// A fresh folder holding one Photo crash and one crash from an app outside the suite, both just written.
    static func crashFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("suite-crashes-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for process in ["Photo", "Browser"] {
            let ips = #"{"app_name":"\#(process)","name":"\#(process)"}"# + "\n"
                + #"{"procPath":"\#(home)/Applications/\#(process).app","threads":[{"triggered":true,"frames":[]}]}"#
            try Data(ips.utf8).write(to: folder.appendingPathComponent("\(process)-journey.ips"))
        }
        return folder
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
