// DesignJourneyTests+TextBox.swift: a text box fits its text (packet
// docs/blueprints/design/features/canvas-basics.md, Journey steps item 3,
// CB-b). On the `cards` fixture at 1024 × 768, every step with the mouse on
// visible controls: a clicked text box hugs "A longer line of text" (W over
// 120, H at least 16); Title at size 48 refits (H at least 48, W grown); a
// box dragged 150 pt wide keeps its width and wraps two sentences onto more
// than one line. Written before its code (lead.md, contract rule 13): CB-4
// writes it skipped, and CB-6 turns it on once the window commits an open edit
// with its measured extent. `-DesignFixture` arrives with design-window; the
// skip covers that too. Frame fields are SuiteUI ScrubFields, read by their
// names ("Width", "Height") and their spoken values ("150 points").
import XCTest

final class DesignTextBoxJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// The page of `cards` is 1440 × 1024 points; Desktop fills it.
    static let pageWidth = 1440.0
    /// The layer ids `cards` opens with (DesignFixtures), so a new row is the one not in this list.
    static let fixtureLayers = Set((1...10).map { "design.layer.node-\($0)" })
    /// Title's row in Layers.
    static let titleRow = "design.layer.node-5"
    /// The text Size field. Not built yet: style-rows ST-4b adds it under the
    /// `design.inspector.<name>` rule (style-rows.md, Definition of done); found by
    /// its label "Size" when the id differs.
    static let sizeField = "design.inspector.text-size"

    /// CB-b: a clicked box grows with its text, a size change refits it, a dragged box wraps.
    @MainActor func testTextBoxFitsItsText() throws {
        throw XCTSkip("waits on CB-6")
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let canvas = design.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "the cards fixture showed no page (suite.canvas)")
        let tools = design.element("suite.tools").buttons
        XCTAssert(tools["Text"].waitForExistence(timeout: 5), "no Text in the tool box (suite.tools)")

        // A clicked box on Desktop's blank area, left of the cards and below them: (72, 870) on the page.
        tools["Text"].click()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.85)).click()
        design.app.typeKey("a", modifierFlags: .command)
        design.app.typeText("A longer line of text")
        design.shot("text-fit-typing")
        commitByClickingBlank(design)
        XCTAssert(design.app.buttons["Undo Add Text"].waitForExistence(timeout: 5), "typing text made no undo step")

        // Its row in Layers: the box hugs the line, wider than the old 120 pt default, one line tall.
        let row = newLayerRow(design)
        XCTAssert(row.waitForExistence(timeout: 5), "no Layers row for the new text")
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
        let width = frameValue(design, "Width"), height = frameValue(design, "Height")
        XCTAssertGreaterThan(width ?? 0, 120, "the clicked box doesn't fit \"A longer line of text\": W \(String(describing: width))")
        XCTAssertGreaterThanOrEqual(height ?? 0, 16, "the clicked box is shorter than a line: H \(String(describing: height))")
        design.shot("text-fit-auto")

        // Title at size 48: the box refits, at least 48 tall and wider than before.
        let title = design.element("suite.sidebar").descendants(matching: .any)[Self.titleRow].firstMatch
        XCTAssert(title.waitForExistence(timeout: 5), "no Title row in Layers (\(Self.titleRow))")
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
        let widthBefore = frameValue(design, "Width")
        let size = sizeField(design)
        XCTAssert(size.waitForExistence(timeout: 5), "no text Size field in the inspector")
        size.click()
        design.app.typeKey("a", modifierFlags: .command)
        design.app.typeText("48\r")
        XCTAssert(design.app.buttons["Undo Change Text Style"].waitForExistence(timeout: 5), "the Size field made no undo step")
        let titleHeight = frameValue(design, "Height"), titleWidth = frameValue(design, "Width")
        XCTAssertGreaterThanOrEqual(titleHeight ?? 0, 48, "Title at size 48 is cut off: H \(String(describing: titleHeight))")
        XCTAssertGreaterThan(titleWidth ?? 0, widthBefore ?? .infinity, "Title's box didn't widen at size 48")
        design.shot("text-fit-size")

        // A box dragged 150 pt wide on the blank area at (432, 768) keeps its width and wraps.
        tools["Text"].click()
        let points = Double(canvas.frame.width) / Self.pageWidth
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.75))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 150 * points, dy: 24 * points)))
        design.app.typeKey("a", modifierFlags: .command)
        design.app.typeText("The first sentence runs past the box. The second one wraps below it.")
        design.shot("text-fit-wrapping")
        commitByClickingBlank(design)
        let wrapped = newLayerRow(design, skipping: row.identifier)
        XCTAssert(wrapped.waitForExistence(timeout: 5), "no Layers row for the dragged text")
        wrapped.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
        let fixedWidth = frameValue(design, "Width"), fixedHeight = frameValue(design, "Height")
        XCTAssertEqual(fixedWidth ?? 0, 150, accuracy: 0.5, "the dragged box didn't keep its 150 pt width")
        XCTAssertGreaterThan(fixedHeight ?? 0, 24, "the dragged box didn't grow down past one line: H \(String(describing: fixedHeight))")
        design.shot("text-fit-fixed")
    }

    /// Clicks the canvas's blank area, (864, 921) on the page, below the cards: it commits an open edit.
    @MainActor private func commitByClickingBlank(_ design: Journey) {
        design.element("suite.canvas").coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.9)).click()
        XCTAssert(Self.waitForGone(design.element("design.text")), "the click on the blank area left the text editor open")
    }

    /// The first Layers row that isn't one of the fixture's layers or `skipping`.
    @MainActor private func newLayerRow(_ design: Journey, skipping: String? = nil) -> XCUIElement {
        let rows = design.element("suite.sidebar").descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'design.layer.'"))
        for _ in 0..<25 {
            let found = rows.allElementsBoundByIndex.first {
                !Self.fixtureLayers.contains($0.identifier) && $0.identifier != skipping
            }
            if let found { return found }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return rows.matching(NSPredicate(format: "identifier == 'design.layer.none'")).firstMatch
    }

    /// The text Size field: its id once style-rows ST-4b gives it one, else the inspector's field labelled Size.
    @MainActor private func sizeField(_ design: Journey) -> XCUIElement {
        let byID = design.element(Self.sizeField)
        if byID.exists { return byID }
        return design.element("suite.inspector").descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Size")).firstMatch
    }

    /// The number a Frame field (Width, Height) reads, from its spoken value ("1,440 points").
    @MainActor private func frameValue(_ design: Journey, _ name: String) -> Double? {
        let field = design.element("suite.inspector").descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "no \(name) field in the inspector")
        let spoken = field.value as? String ?? ""
        guard let word = spoken.split(separator: " ").first else { return nil }
        return Double(word.filter { character in character.isNumber || character == "." || character == "-" })
    }

    /// Whether `element` is gone within five seconds.
    @MainActor private static func waitForGone(_ element: XCUIElement) -> Bool {
        for _ in 0..<25 {
            if !element.exists { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }
}
