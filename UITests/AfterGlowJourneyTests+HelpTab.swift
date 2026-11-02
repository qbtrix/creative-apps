// AfterGlowJourneyTests+HelpTab.swift (report-problem RP-3, the packet's keyboard row): XJ-RP's Tab walk over the
// Report a Problem sheet, kept apart from the Help journey because it needs keyboard navigation on. AppKit reads
// that from the Mac's global setting (#5897), so on a Mac with it off this journey skips, saying why, while the
// Help journey (+Help) still runs in full.
import AppKit
import XCTest

final class AfterGlowHelpTabJourneyTests: XCTestCase {
    /// The packet's keyboard row, Tab: with keyboard navigation on, Tab reaches the note and every sheet button.
    /// AppKit reads keyboard navigation from the Mac's global setting, not from a launch argument
    /// (`-AppleKeyboardUIMode 2` changes nothing), so this skips, saying so, on a Mac with it off.
    @MainActor func testReportAProblemByTab() throws {
        let mode = CFPreferencesCopyAppValue("AppleKeyboardUIMode" as CFString, kCFPreferencesAnyApplication) as? Int ?? 0
        try XCTSkipUnless(mode & 2 != 0, "keyboard navigation is off on this Mac (AppleKeyboardUIMode \(mode)), so Tab visits text fields only")
        let crashes = try AfterGlowHelpJourneyTests.crashFolder()
        defer { try? FileManager.default.removeItem(at: crashes) }
        let launcher = SuiteHarness(self).launch(fixture: "firstLaunch", arguments: ["-SuiteCrashDir", crashes.path])
        AfterGlowHelpJourneyTests.openHelp(launcher).menuItems["Report a Problem…"].click()
        let sheet = launcher.app.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: 10), "Help > Report a Problem… opened no sheet")
        let stops = ["note", "copy", "save", "email", "close"]
        func focused(_ control: String) -> Bool {
            sheet.descendants(matching: .any).matching(identifier: "suite.help.report." + control).allElementsBoundByIndex
                .contains { ($0.value(forKey: "hasKeyboardFocus") as? Bool) ?? false }
        }
        var reached: Set<String> = []
        var walk: [String] = []
        for _ in 0..<20 where reached.count < stops.count {
            launcher.press(.tab)
            reached.formUnion(stops.filter(focused))
            walk.append(sheet.descendants(matching: .any).matching(NSPredicate(format: "hasKeyboardFocus == true"))
                .allElementsBoundByIndex.map(\.identifier).joined(separator: "+"))
        }
        XCTAssertEqual(stops.filter { !reached.contains($0) }, [], "Tab never reached these controls; focus walked \(walk)")
        launcher.shot("help-report-tab")
    }
}
