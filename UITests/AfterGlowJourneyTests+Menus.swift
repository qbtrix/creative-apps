// AfterGlowJourneyTests+Menus.swift (no-placeholders NP-2, MJ-NP): every launcher menu, opened by a click, holds
// no Check for Updates…, Add from Clipboard or Assets (their stubs are out of the beta's scenes), and Edit keeps
// the system's Cut, Copy and Paste. Items are found by title only (#4647); the menu shot is a screen shot.
import XCTest

final class AfterGlowMenusJourneyTests: XCTestCase {
    /// The titles no launcher menu may hold in the beta.
    static let placeholders = ["Check for Updates…", "Add from Clipboard", "Assets"]

    @MainActor func testNoPlaceholderItems() {
        let launcher = SuiteHarness(self).launch(fixture: "firstLaunch", arguments: [], skipOnboarding: true)
        XCTAssert(launcher.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window")
        let menus = launcher.app.menuBars.firstMatch.menuBarItems
        XCTAssert(menus.firstMatch.waitForExistence(timeout: 10), "no menu bar")
        // Index 0 is the Apple menu, which belongs to the system; index 1 is the app menu.
        for index in 1..<menus.count {
            let menu = menus.element(boundBy: index)
            let title = menu.title
            menu.click()
            if !menu.menuItems.firstMatch.waitForExistence(timeout: 3) { menu.click() }
            XCTAssert(menu.menuItems.firstMatch.waitForExistence(timeout: 3), "the \(title) menu didn't open")
            for item in Self.placeholders {
                XCTAssertFalse(menu.menuItems[item].exists, "the \(title) menu still shows the placeholder \(item)")
            }
            if index == 1 { launcher.shot("launcher-menu-app", screen: true) }
            if title == "Edit" {
                for item in ["Cut", "Copy", "Paste"] {
                    XCTAssert(menu.menuItems[item].exists, "Edit on Home has no system \(item)")
                }
            }
            launcher.press(.escape)
        }
    }
}
