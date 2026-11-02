// HaloJourneyTests+Filter.swift: HJ-AJ, blur a title layer (adjust-everywhere AJ-13;
// docs/blueprints/suiteui/features/adjust-everywhere.md). On `-HaloSample empty` it adds Layer > New > Text, then
// Layer > Add Filter > Blur > Gaussian Blur: FILTERS shows under the layer's sections with one row and its Radius
// slider (`halo.inspector.filter.gaussian-blur.radius`). It types 6 into Radius, scrubs the slider (one step for
// the whole drag), types 2, and hides the row with its eye (`.hide`), reading the Edit menu's first item after
// each. The Model half is HaloModelTests' HaloFilterIntentTests. One shot per step, `halo-filter-<step>`.
import XCTest

final class HaloFilterJourneyTests: XCTestCase {
    private static let radius = "halo.inspector.filter.gaussian-blur.radius", hide = "halo.inspector.filter.gaussian-blur.hide"

    /// HJ-AJ: add a Gaussian Blur to a title layer, set its radius, scrub it, change it and hide it.
    @MainActor func testBlurTitleLayer() {
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "empty", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. A title layer, then Layer > Add Filter > Blur > Gaussian Blur: FILTERS shows its Radius row.
        halo.choose(menu: ["Layer", "New", "Text"])
        halo.choose(menu: ["Layer", "Add Filter", "Blur", "Gaussian Blur"])
        let radius = halo.element(Self.radius)
        XCTAssert(radius.waitForExistence(timeout: 10), "Add Filter > Gaussian Blur shows no Radius row (\(Self.radius))")
        expectUndo("Undo Gaussian Blur", halo)
        halo.shot("filter-1-added")

        // 2. Radius 6.
        type("6", into: radius, halo)
        expectValue(radius, 6)
        expectUndo("Undo Gaussian Blur", halo)
        halo.shot("filter-2-radius-6")

        // 3. Scrub Radius: the drag is one step, still named for the filter.
        halo.reveal(radius)
        halo.scrub(radius, seconds: 1)
        expectUndo("Undo Gaussian Blur", halo)
        halo.shot("filter-3-scrubbed")

        // 4. Radius 2.
        type("2", into: radius, halo)
        expectValue(radius, 2)
        halo.shot("filter-4-radius-2")

        // 5. Hide it: one Hide Filter step, the row stays.
        let hide = halo.element(Self.hide)
        halo.reveal(hide)
        XCTAssert(hide.waitForExistence(timeout: 5) && hide.isEnabled, "the row has no enabled hide toggle (\(Self.hide))")
        hide.click()
        expectUndo("Undo Hide Filter", halo)
        XCTAssert(radius.exists, "hiding the filter removed its row")
        halo.shot("filter-5-hidden")
    }

    // MARK: - Helpers

    /// Double-clicks the slider row to type, types `text` and presses Return.
    @MainActor private func type(_ text: String, into row: XCUIElement, _ halo: Journey) {
        halo.reveal(row)
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
        halo.app.typeText(text)
        halo.press(.return)
    }

    /// The slider reads `number` (its value as a number, or text that starts with it) within five seconds.
    @MainActor private func expectValue(_ row: XCUIElement, _ number: Double) {
        let held = FirstFive.wait(5) {
            if let n = row.value as? NSNumber { return n.doubleValue == number }
            return (row.value as? String).map { Double($0.split(separator: " ").first ?? "") == number } ?? false
        }
        XCTAssert(held, "the slider reads \(String(describing: row.value)), not \(number)")
    }

    /// The Edit menu's first item reads `title`; the menu is closed again.
    @MainActor private func expectUndo(_ title: String, _ halo: Journey) {
        let edit = halo.reachable(menu: ["Edit"])
        let first = edit.menus.firstMatch.children(matching: .menuItem).firstMatch
        XCTAssert(first.waitForExistence(timeout: 3), "the Edit menu shows no items")
        XCTAssertEqual(first.title, title, "the Edit menu's first item")
        halo.press(.escape)
        XCTAssert(halo.menusClosed(), "a menu stayed open after Escape")
    }
}
