// DesignJourneyTests+Page.swift: CB-c, the page's size and the layers past
// its edge (packet docs/blueprints/design/features/canvas-basics.md, Journey
// steps 4). On `-DesignFixture cards` at 1024 × 768 it clicks the page's row
// in Pages and finds the inspector's Width 1440 and Height 1024
// (`design.inspector.page-width`, `design.inspector.page-height`), clicks
// Width, types 800 and presses Return: the status line reads "800 × 1024 pt"
// and the toolbar's Undo (`design.bar.undo`) reads "Undo Change Page Size".
// It shoots the canvas, where Desktop's part past 800 still shows, dimmed (the
// shot is attached; the pixels are CB-9's snapshot), then clicks Undo and
// finds Width back at 1440. Every step uses the mouse on visible controls but
// the typed number. Written before its code (lead.md, contract rule 13): the
// fixture argument arrives with design-window and the fields with CB-9, which
// turns it on. A ScrubField reads its number as its value, spoken with its
// unit, and a plain Text its words as its value, so both are read by label or value.
import XCTest

final class DesignPageJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]

    /// CB-c: Width and Height in the inspector, one undo step, Desktop dimmed past the page.
    @MainActor func testPageSizeAndPastThePage() throws {
        throw XCTSkip("waits on CB-9")
        try walkPageSize()
    }

    /// The journey itself, which CB-9 runs once it drops the skip above.
    @MainActor private func walkPageSize() throws {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "the cards fixture showed no page")

        // 1. Click the page's row in Pages: the inspector shows Width 1440 and Height 1024.
        let sidebar = design.element("suite.sidebar")
        let rows = sidebar.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'design.page.row.'"))
        XCTAssert(rows.firstMatch.waitForExistence(timeout: 5), "no page row in Pages (design.page.row.<id>)")
        rows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
        let inspector = design.element("suite.inspector")
        let width = inspector.descendants(matching: .any)["design.inspector.page-width"].firstMatch
        let height = inspector.descendants(matching: .any)["design.inspector.page-height"].firstMatch
        XCTAssert(width.waitForExistence(timeout: 5), "no Width in the inspector (design.inspector.page-width)")
        XCTAssert(height.exists, "no Height in the inspector (design.inspector.page-height)")
        XCTAssert(waitUntil { self.reads(width, "1440") }, "Width reads \(text(width)), not 1440")
        XCTAssert(reads(height, "1024"), "Height reads \(text(height)), not 1024")
        design.shot("page-size")

        // 2. Click Width, type 800, Return: the status line and the toolbar's Undo say so.
        width.click()
        let field = inspector.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking Width opened no field")
        design.press(character: "a", .command)
        field.typeText("800")
        design.press(.return)
        XCTAssert(waitUntil { self.reads(width, "800") }, "Width reads \(text(width)), not 800")
        let status = design.element("suite.status")
        let size = status.staticTexts.matching(
            NSPredicate(format: "label == %@ OR value == %@", "800 × 1024 pt", "800 × 1024 pt")).firstMatch
        XCTAssert(size.waitForExistence(timeout: 5), "the status line doesn't read 800 × 1024 pt")
        let undo = design.element("design.bar.undo")
        XCTAssert(waitUntil { undo.label == "Undo Change Page Size" }, "the toolbar's Undo reads \(undo.label), not Undo Change Page Size")

        // 3. Desktop's part past 800 still shows, dimmed: the canvas is shot and attached.
        design.shot("page-past-the-edge", element: design.element("suite.viewport"))

        // 4. Click Undo: Width reads 1440 again.
        undo.click()
        XCTAssert(waitUntil { self.reads(width, "1440") }, "Undo left Width at \(text(width)), not 1440")
        design.shot("page-size-undone")
    }

    /// Whether `element`'s number, read by label or value ("1440 pt"), is `number`.
    @MainActor private func reads(_ element: XCUIElement, _ number: String) -> Bool {
        let words = text(element)
        return words == number || words.hasPrefix(number + " ")
    }

    /// What an element reads: its value where macOS puts a field's number or a Text's words, else its label.
    @MainActor private func text(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }

    /// Whether `condition` holds within about three seconds.
    @MainActor private func waitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
