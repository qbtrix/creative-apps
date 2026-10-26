// DesignJourneyTests+TextStyle.swift (text-style TS-3, DJ-TS; on since TS-8): on `cards` at 1024 × 768, a
// dragged 150 pt text box takes two sentences; the shared rows (`suite.text.*`) set Italic, Justify, Line Height
// 1.5 and Letter Spacing 20, each one step that changes the canvas; Undo steps back one at a time. No family-pick
// refit step: `services.text` isn't wired in the app, so the Model tests cover it.
import XCTest

final class DesignTextStyleJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// The page of `cards` is 1440 × 1024 points; Desktop fills it.
    static let pageWidth = 1440.0
    /// The layer ids `cards` opens with (DesignFixtures), so a new row is the one not in this list.
    static let fixtureLayers = Set((1...10).map { "design.layer.node-\($0)" })

    /// DJ-TS: Italic, Justify, Line Height and Letter Spacing each redraw the box as one step, and undo in turn.
    @MainActor func testParagraphStyle() throws {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let canvas = design.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "the cards fixture showed no page (suite.canvas)")
        let tools = design.element("suite.tools").buttons
        XCTAssert(tools["Text"].waitForExistence(timeout: 5), "no Text in the tool box (suite.tools)")

        // A box dragged 150 pt wide on the blank area at (432, 768), two sentences that wrap.
        tools["Text"].click()
        let points = Double(canvas.frame.width) / Self.pageWidth
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.75))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 150 * points, dy: 24 * points)))
        design.app.typeText("The first sentence runs past the box. The second one wraps below it.")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.9)).click()
        XCTAssert(design.element("design.text").waitForNonExistence(timeout: 5), "the click on the blank area left the text editor open")
        let row = design.element("suite.sidebar").descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH 'design.layer.node-' AND NOT (identifier IN %@)", Array(Self.fixtureLayers))).firstMatch
        XCTAssert(row.waitForExistence(timeout: 5), "no Layers row for the dragged text")
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
        let inspector = design.element("suite.inspector")
        let italic = inspector.descendants(matching: .any)["suite.text.italic"].firstMatch
        XCTAssert(italic.waitForExistence(timeout: 5), "no text style rows (suite.text.italic) for the selected text")
        design.shot("text-style-plain")

        // Italic: one Font step, and the box redraws slanted.
        var before = canvas.screenshot().pngRepresentation
        (italic.checkBoxes.firstMatch.exists ? italic.checkBoxes.firstMatch : italic).click()
        expectStep(design, "Font", changed: &before)
        design.shot("text-style-italic")

        // Justify: one Alignment step; the wrapped lines spread to the box's width.
        let justify = inspector.descendants(matching: .any)["suite.text.alignment.justified"].firstMatch
        XCTAssert(justify.waitForExistence(timeout: 5), "no Justify (suite.text.alignment.justified)")
        justify.click()
        expectStep(design, "Alignment", changed: &before)
        design.shot("text-style-justified")

        // Line Height 1.5 and Letter Spacing 20, each typed into its bar with Return: one step each.
        typeInto(design, "suite.text.line-height", "1.5")
        expectStep(design, "Line Height", changed: &before)
        design.shot("text-style-line-height")
        typeInto(design, "suite.text.tracking", "20")
        expectStep(design, "Letter Spacing", changed: &before)
        design.shot("text-style-tracking")

        // Undo steps back one control at a time, newest first.
        for (name, next) in [("Letter Spacing", "Line Height"), ("Line Height", "Alignment"), ("Alignment", "Font"), ("Font", "Add Text")] {
            design.app.buttons["Undo \(name)"].click()
            XCTAssert(design.app.buttons["Undo \(next)"].waitForExistence(timeout: 5), "undoing \(name) didn't leave Undo \(next)")
        }
        design.shot("text-style-undone")
    }

    /// The top bar reads "Undo `name`" and the canvas picture differs from `before`, which becomes the new picture.
    @MainActor private func expectStep(_ design: Journey, _ name: String, changed before: inout Data) {
        XCTAssert(design.app.buttons["Undo \(name)"].waitForExistence(timeout: 5), "the \(name) control made no undo step")
        let canvas = design.element("suite.canvas")
        var after = canvas.screenshot().pngRepresentation
        for _ in 0..<10 where after == before {
            Thread.sleep(forTimeInterval: 0.2)
            after = canvas.screenshot().pngRepresentation
        }
        XCTAssertNotEqual(after, before, "\(name) didn't change the canvas")
        before = after
    }

    /// Clicks the bar `id` in the inspector, which opens its typing field, and types `value` over it with Return.
    @MainActor private func typeInto(_ design: Journey, _ id: String, _ value: String) {
        let inspector = design.element("suite.inspector")
        let bar = inspector.descendants(matching: .any)[id].firstMatch
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(id) bar in the inspector")
        bar.click()
        XCTAssert(inspector.textFields.firstMatch.waitForExistence(timeout: 5), "clicking \(id) opened no typing field")
        design.app.typeKey("a", modifierFlags: .command)
        design.app.typeText("\(value)\r")
    }
}
