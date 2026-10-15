// HaloJourneyTests+Menus.swift: whether a menu is still up. Once the menu
// bar has been used, AppKit keeps every menu bar menu (and its submenus) in
// the accessibility tree while it is closed, with an empty frame at the
// screen's bottom left ({{0, 768}, {0, 0}} in run 38767265986's UI
// hierarchy), so `app.menus` never runs empty after a menu is chosen or
// dismissed. A menu is up only while its frame has area, and the menu a
// click just opened is the one with a frame (`shownMenu`).
import XCTest

extension Journey {
    /// Whether any of the app's menus is on screen.
    func aMenuIsUp() -> Bool {
        app.menus.allElementsBoundByIndex.contains { !$0.frame.isEmpty }
    }

    /// The menu on screen, within `timeout` seconds: the first of the app's
    /// menus with a frame, so a closed menu bar menu (the Apple menu comes
    /// first) is never taken for a pop-up that just opened.
    func shownMenu(timeout: TimeInterval = 3) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let menu = app.menus.allElementsBoundByIndex.first(where: { !$0.frame.isEmpty }) { return menu }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        return nil
    }

    /// Waits up to `timeout` seconds for every menu to leave the screen;
    /// whether they all did.
    @discardableResult
    func menusClosed(timeout: TimeInterval = 2) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while aMenuIsUp() {
            guard Date() < deadline else { return false }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return true
    }
}
