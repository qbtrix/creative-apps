// FlareJourneyTests+Sidebar.swift: how Flare's journeys pick a SCENES or LAYERS row. A row is clicked in its blank
// space, midway between its name and its first toggle (Hide), or at 60% of its width when it has none (a scene row):
// a click on the name itself doesn't select the row, because SuiteUI's rename double-click on the title takes the
// List's single click (#2496), so the workspace never hears the pick and Edit > Copy stays "Select a layer first."
// (#2730). The same route as Design's `clickDesignLayer`. The pick then waits for the row to read selected, so a
// menu opened next reads the new selection.
import XCTest

extension Journey {
    /// The sidebar's outline row whose name is exactly `title`.
    func sidebarRow(_ title: String) -> XCUIElement {
        element("suite.sidebar").outlineRows.containing(Self.named(title)).firstMatch
    }

    /// Clicks the sidebar row named `title` off its name (#2496) and waits until it reads selected.
    func pickSidebarRow(_ title: String) {
        let row = sidebarRow(title)
        XCTAssert(row.waitForExistence(timeout: 5), "the sidebar has no \(title) row")
        let name = row.staticTexts.matching(Self.named(title)).firstMatch
        let toggle = row.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "suite.sidebar.")).firstMatch
        let frame = row.frame
        var dx = 0.6
        if frame.width > 0, name.exists, toggle.exists, name.frame.maxX < toggle.frame.minX {
            dx = Double((name.frame.maxX + toggle.frame.minX) / 2 - frame.minX) / Double(frame.width)
        }
        row.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.5)).click()
        var selected = row.isSelected
        for _ in 0..<25 where !selected {
            Thread.sleep(forTimeInterval: 0.2)
            selected = row.isSelected
        }
        XCTAssert(selected, "clicking the \(title) row didn't select it")
    }

    /// An element whose label or value is exactly `title`.
    private static func named(_ title: String) -> NSPredicate {
        NSPredicate(format: "label == %@ OR value == %@", title, title)
    }
}
