// Journey+Menus.swift: which menus are up, for every app's journeys, and
// the inspector's dropdowns. Once the menu bar has
// been used, AppKit keeps every menu bar menu (and its submenus) in the
// accessibility tree while it is closed, with an empty frame at the screen's
// bottom left ({{0, 768}, {0, 0}} in run 38767265986's UI hierarchy), so
// `app.menus` never runs empty after a menu is chosen or dismissed, and its
// first match is the closed Apple menu. A menu is up only while its frame has
// area. Menus are read from one snapshot of the app: an element bound by
// index from `app.menus` can vanish between the count and the read while a
// menu closes, which failed a run with "No matches found" (run 38814195169).
// An inspector row gives its identifier to its label text as well as its
// menu button, so `inspectorMenu` matches the button by type.
import XCTest

extension Journey {
    /// Whether any of the app's menus is on screen.
    func aMenuIsUp() -> Bool {
        !shownMenus().isEmpty
    }

    /// The item titles of the menu a click just opened, within `timeout`
    /// seconds: the first of the app's menus with a frame. Nil when none opens.
    func shownMenuTitles(timeout: TimeInterval = 3) -> [String]? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let menu = shownMenus().first {
                var titles: [String] = []
                func walk(_ element: any XCUIElementSnapshot) {
                    if element.elementType == .menuItem { titles.append(element.title) }
                    element.children.forEach(walk)
                }
                walk(menu)
                return titles
            }
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

    /// The inspector's dropdown identified `id` or labelled `label`: its menu
    /// button, never the row's label text, which carries the same identifier.
    func inspectorMenu(_ id: String, label: String) -> XCUIElement {
        let types = [XCUIElement.ElementType.menuButton, .popUpButton, .button].map { NSNumber(value: $0.rawValue) }
        return element("suite.inspector").descendants(matching: .any).matching(
            NSPredicate(format: "elementType IN %@ AND (identifier == %@ OR label == %@)", types, id, label)
        ).firstMatch
    }

    /// Clicks the item titled `title` in the menu on screen, within `timeout`
    /// seconds (a closed menu bar menu's item of the same title isn't
    /// hittable), then waits for the menu to close. Whether the item showed.
    @discardableResult
    func chooseShownMenuItem(_ title: String, timeout: TimeInterval = 3) -> Bool {
        let matches = app.menuItems.matching(NSPredicate(format: "title == %@", title))
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let item = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) {
                item.click()
                menusClosed()
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        return false
    }

    /// The app's menus with a frame, from one snapshot; none when it can't be taken.
    private func shownMenus() -> [any XCUIElementSnapshot] {
        guard let root = try? app.snapshot() else { return [] }
        var shown: [any XCUIElementSnapshot] = []
        func walk(_ element: any XCUIElementSnapshot) {
            if element.elementType == .menu, !element.frame.isEmpty { shown.append(element) }
            element.children.forEach(walk)
        }
        walk(root)
        return shown
    }
}
