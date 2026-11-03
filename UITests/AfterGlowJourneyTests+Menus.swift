// AfterGlowJourneyTests+Menus.swift (no-placeholders NP-2, MJ-NP): every launcher menu, opened by a click, holds
// no Check for Updates…, Add from Clipboard or Assets (their stubs are out of the beta's scenes), and Edit keeps
// the system's Cut, Copy and Paste. Items are found by title only (#4647); the menu shot is a screen shot.
// testViewAndClearAct (#6203): View's Hide Sidebar and Hide Inspector hide their columns and flip to Show,
// and File > Open Recent > Clear Menu empties the recents, so its item turns off.
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

    /// #6203: the View and Open Recent items the audit found dead each act on a click.
    @MainActor func testViewAndClearAct() {
        let home = SuiteHarness(self).launch(fixture: "weekOfWork", arguments: [], skipOnboarding: true)
        XCTAssert(home.element("suite.sidebar").waitForExistence(timeout: 30), "the home window has no sidebar")
        let bar = home.app.menuBars.firstMatch
        for (hide, show, column) in [("Hide Sidebar", "Show Sidebar", "suite.sidebar"),
                                     ("Hide Inspector", "Show Inspector", "suite.inspector")] {
            let view = bar.menuBarItems["View"]
            view.click()
            XCTAssert(view.menuItems[hide].waitForExistence(timeout: 5), "View has no \(hide)")
            XCTAssert(view.menuItems[hide].isEnabled, "View > \(hide) is off")
            view.menuItems[hide].click()
            XCTAssert(home.element(column).waitForNonExistence(timeout: 5), "View > \(hide) left \(column) shown")
            view.click()
            XCTAssert(view.menuItems[show].waitForExistence(timeout: 5), "View doesn't offer \(show) after \(hide)")
            view.menuItems[show].click()
            XCTAssert(home.element(column).waitForExistence(timeout: 5), "View > \(show) didn't bring \(column) back")
        }
        let file = bar.menuBarItems["File"]
        file.click()
        let recent = file.menuItems["Open Recent"]
        XCTAssert(recent.waitForExistence(timeout: 5), "File has no Open Recent")
        recent.hover()
        let clear = recent.menuItems["Clear Menu"]
        XCTAssert(clear.waitForExistence(timeout: 5) && clear.isEnabled, "Clear Menu is off with recents shown")
        clear.click()
        file.click()
        recent.hover()
        XCTAssert(recent.menuItems["Clear Menu"].waitForExistence(timeout: 5), "Open Recent lost Clear Menu")
        XCTAssertFalse(recent.menuItems["Clear Menu"].isEnabled, "Clear Menu stayed on after clearing")
        home.shot("launcher-menu-cleared", screen: true)
        home.press(.escape)
        home.press(.escape)
    }
}
