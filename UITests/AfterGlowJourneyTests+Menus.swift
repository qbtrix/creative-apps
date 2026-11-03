// AfterGlowJourneyTests+Menus.swift (no-placeholders NP-2, MJ-NP): every launcher menu, opened by a click, holds
// no Check for Updates…, Add from Clipboard or Assets (their stubs are out of the beta's scenes), and Edit keeps
// the system's Cut, Copy and Paste. Items are found by title only (#4647); the menu shot is a screen shot.
// testViewAndClearAct (#6203): View's sidebar and inspector toggles hide their columns and bring them back,
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

    /// #6203: the View and Open Recent items the audit found dead each act on a click. The View toggles are
    /// found by suffix and proved by their column: AX can read the system's sidebar item as Show while it draws Hide.
    @MainActor func testViewAndClearAct() {
        let home = SuiteHarness(self).launch(fixture: "weekOfWork", arguments: [], skipOnboarding: true)
        XCTAssert(home.element("suite.sidebar").waitForExistence(timeout: 30), "the home window has no sidebar")
        let bar = home.app.menuBars.firstMatch
        for (name, column) in [("Sidebar", "suite.sidebar"), ("Inspector", "suite.inspector")] {
            let shown = { home.element(column).exists && home.element(column).isHittable }
            XCTAssert(Self.wait(for: shown), "\(column) isn't shown at launch")
            let toggle = Self.open(bar.menuBarItems["View"], to: name)
            XCTAssert(toggle.exists && toggle.isEnabled, "View has no working \(name) toggle")
            toggle.click()
            XCTAssert(Self.wait(for: { !shown() }), "View > Hide \(name) left \(column) shown")
            home.shot("launcher-view-hidden-\(name.lowercased())", screen: true)
            Self.open(bar.menuBarItems["View"], to: name).click()
            XCTAssert(Self.wait(for: shown), "View > Show \(name) didn't bring \(column) back")
        }
        let file = bar.menuBarItems["File"]
        let recent = Self.open(file, to: "Open Recent")
        XCTAssert(recent.exists, "File has no Open Recent")
        recent.hover()
        let clear = recent.menuItems["Clear Menu"]
        XCTAssert(clear.waitForExistence(timeout: 5) && clear.isEnabled, "Clear Menu is off with recents shown")
        clear.click()
        Self.open(file, to: "Open Recent").hover()
        XCTAssert(recent.menuItems["Clear Menu"].waitForExistence(timeout: 5), "Open Recent lost Clear Menu")
        XCTAssertFalse(recent.menuItems["Clear Menu"].isEnabled, "Clear Menu stayed on after clearing")
        home.shot("launcher-menu-cleared", screen: true)
        home.press(.escape)
        home.press(.escape)
    }

    /// Clicks `menu` open (again if the first click lands while another menu closes) and returns its item ending in `suffix`.
    @MainActor static func open(_ menu: XCUIElement, to suffix: String) -> XCUIElement {
        let item = AfterGlowJourneyTests.item(endingWith: suffix, in: menu)
        menu.click()
        if !item.waitForExistence(timeout: 3) { menu.click() }
        _ = item.waitForExistence(timeout: 5)
        return item
    }

    /// Polls `condition` for up to five seconds.
    @MainActor static func wait(for condition: () -> Bool) -> Bool {
        for _ in 0..<25 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
