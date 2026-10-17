// DesignJourneyTests+Text.swift: J11, a text layer's family, size, weight and
// alignment (packet docs/blueprints/design/features/style-rows.md, Journey
// steps item 2, SR-t). On `cards` at 1024 × 768, live services, every step with
// the mouse on visible controls: click Title's row in Layers; click the Size
// field, type 32, Return: it reads 32 and the top bar's Undo reads "Undo Change
// Text Style"; click Bold in the weight chips, Center in the alignment chips and
// another family in the Family menu; select A and Title again and each reads
// back; click A's row: the Text rows are disabled with "A isn't a text layer.";
// click the top bar's zoom-out until the status line reads 50%; double-click
// Title on the canvas, type, press Return: the committed text's frame (the
// inspector's X, Y, W and H, scaled to the canvas) equals the editor's within
// 1 pt, and Undo reads "Undo Edit Text". The canvas half (size 32 draws about
// twice as tall as 16) is DesignTextDrawTests (ST-5t): the artwork is one
// accessibility-hidden Canvas, so this journey only attaches the canvas shot at
// size 32 for the contact sheet. Written before its code (lead.md, contract
// rule 13): ST-6b writes it skipped, and ST-5t turns it on once ST-4b's rows
// and its own drawing have merged. The rows' ids follow the
// `design.inspector.<name>` rule; each is also found by its label when the id
// differs. Frame fields are ScrubFields, read by their labels ("X position")
// and spoken values ("100 points"); chips are buttons titled by their choice,
// the picked one selected.
import XCTest

final class DesignTextJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// The page of `cards` is 1440 × 1024 points; Desktop fills it.
    static let pageWidth = 1440.0
    /// Title's and A's rows in Layers (DesignFixtures.cards).
    static let titleRow = "design.layer.node-5", rowA = "design.layer.node-2"
    /// The Text rows ST-4b adds, by id, with the label each is found by otherwise.
    static let familyRow = (id: "design.inspector.text-family", label: "Family")
    static let sizeRow = (id: "design.inspector.text-size", label: "Size")
    static let weightRow = (id: "design.inspector.text-weight", label: "Weight")
    static let alignmentRow = (id: "design.inspector.text-alignment", label: "Alignment")
    /// A point inside Title's box, (130, 52) on the page, at any size from 16 up.
    static let insideTitle = CGVector(dx: 130 / 1440.0, dy: 52 / 1024.0)

    /// J11: the Text rows set Title's style, read back, refuse A, and the inline edit doesn't jump at 50%.
    @MainActor func testTextFontAndSize() throws {
        throw XCTSkip("waits on ST-5t")
        walkTextStyle()
    }

    /// The journey itself, which ST-5t runs once it drops the skip above.
    @MainActor private func walkTextStyle() {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let canvas = design.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "the cards fixture showed no page (suite.canvas)")
        let undo = design.element("design.bar.undo")

        // 1. Title's row in Layers, then Size 32 typed with Return: one step, and the field reads 32.
        clickRow(design, Self.titleRow, "Title")
        let size = row(design, Self.sizeRow)
        XCTAssert(size.waitForExistence(timeout: 5), "no text Size field in the inspector (\(Self.sizeRow.id))")
        size.click()
        design.press(character: "a", .command)
        design.app.typeText("32")
        design.press(.return)
        XCTAssert(Self.waitForLabel(undo, "Undo Change Text Style"), "the Size field made no step (Undo reads \(undo.label))")
        XCTAssert(Self.waitUntil { Self.number(size) == 32 }, "Size reads \(Self.text(size)), not 32")
        design.shot("text-style-size")
        design.shot("text-style-size-32-canvas", element: design.element("suite.viewport"))

        // 2. Bold in the weight chips, Center in the alignment chips, each one step.
        let bold = chip(design, Self.weightRow, "Bold")
        XCTAssert(bold.waitForExistence(timeout: 5), "no Bold in the weight chips (\(Self.weightRow.id))")
        bold.click()
        XCTAssert(Self.waitUntil { bold.isSelected }, "clicking Bold didn't pick it")
        XCTAssertEqual(undo.label, "Undo Change Text Style", "Bold made no Change Text Style step")
        let center = chip(design, Self.alignmentRow, "Center")
        XCTAssert(center.waitForExistence(timeout: 5), "no Center in the alignment chips (\(Self.alignmentRow.id))")
        center.click()
        XCTAssert(Self.waitUntil { center.isSelected }, "clicking Center didn't pick it")
        XCTAssertEqual(undo.label, "Undo Change Text Style", "Center made no Change Text Style step")
        design.shot("text-style-weight-alignment")

        // 3. Another family from the Family menu.
        let family = row(design, Self.familyRow)
        XCTAssert(family.waitForExistence(timeout: 5), "no Family menu in the inspector (\(Self.familyRow.id))")
        let before = Self.text(family)
        family.click()
        let items = design.app.menuItems.matching(NSPredicate(format: "title != '' AND title != %@", before))
        XCTAssert(items.firstMatch.waitForExistence(timeout: 5), "the Family menu offers no family but \(before)")
        let picked = items.firstMatch.title
        items.firstMatch.click()
        XCTAssert(Self.waitUntil { Self.text(family) == picked }, "Family reads \(Self.text(family)), not \(picked)")
        XCTAssertEqual(undo.label, "Undo Change Text Style", "the family made no Change Text Style step")
        design.shot("text-style-family")

        // 4. Select A, then Title again: every row reads back what was set.
        clickRow(design, Self.rowA, "A")
        clickRow(design, Self.titleRow, "Title")
        XCTAssert(Self.waitUntil { Self.number(size) == 32 }, "Size reads \(Self.text(size)) after reselecting Title, not 32")
        XCTAssert(chip(design, Self.weightRow, "Bold").isSelected, "Bold isn't picked after reselecting Title")
        XCTAssert(chip(design, Self.alignmentRow, "Center").isSelected, "Center isn't picked after reselecting Title")
        XCTAssertEqual(Self.text(row(design, Self.familyRow)), picked, "Family doesn't read \(picked) after reselecting Title")
        design.shot("text-style-read-back")

        // 5. A's row: the Text rows are disabled, saying why.
        clickRow(design, Self.rowA, "A")
        let rows = [row(design, Self.familyRow), row(design, Self.sizeRow),
                    chip(design, Self.weightRow, "Bold"), chip(design, Self.alignmentRow, "Center")]
        XCTAssert(Self.waitUntil { rows.allSatisfy { $0.exists && !$0.isEnabled } }, "a Text row is enabled on A, a rectangle")
        let reason = design.element("suite.inspector").descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ OR value == %@ OR title == %@",
                        "A isn't a text layer.", "A isn't a text layer.", "A isn't a text layer.")).firstMatch
        XCTAssert(reason.waitForExistence(timeout: 5), "the disabled Text rows don't say \"A isn't a text layer.\"")
        design.shot("text-style-not-text")

        // 6. Zoom out from the top bar until the status line reads 50%.
        let zoomOut = design.element("design.bar.zoom-out")
        XCTAssert(zoomOut.waitForExistence(timeout: 5), "no zoom-out in the top bar (design.bar.zoom-out)")
        for _ in 0..<8 where !statusReads50(design) { zoomOut.click() }
        XCTAssert(Self.waitUntil { self.statusReads50(design) }, "the status line never read 50% zooming out")

        // 7. Double-click Title, type, Return: the committed box sits where the editor was, one Edit Text step.
        clickRow(design, Self.titleRow, "Title")
        canvas.coordinate(withNormalizedOffset: Self.insideTitle).doubleClick()
        let editor = design.element("design.text")
        XCTAssert(editor.waitForExistence(timeout: 5), "double-clicking Title opened no text editor (design.text)")
        design.press(character: "a", .command)
        design.app.typeText("Big title")
        design.shot("text-style-editing-50")
        let editing = editor.frame
        design.press(.return)
        XCTAssert(Self.waitUntil { !editor.exists }, "Return left the text editor open")
        XCTAssert(Self.waitForLabel(undo, "Undo Edit Text"), "the edit made no Edit Text step (Undo reads \(undo.label))")
        let committed = committedFrame(design)
        for (name, editorEdge, committedEdge) in [
            ("left", editing.minX, committed.minX), ("top", editing.minY, committed.minY),
            ("width", editing.width, committed.width), ("height", editing.height, committed.height),
        ] {
            XCTAssertEqual(Double(committedEdge), Double(editorEdge), accuracy: 1,
                           "the committed text's \(name) jumped from the editor's at 50% (\(committed) vs \(editing))")
        }
        design.shot("text-style-committed-50")
    }

    /// Clicks the Layers row `identifier` (the layer called `name`).
    @MainActor private func clickRow(_ design: Journey, _ identifier: String, _ name: String) {
        let layer = design.element("suite.sidebar").descendants(matching: .any)[identifier].firstMatch
        XCTAssert(layer.waitForExistence(timeout: 5), "no \(name) row in Layers (\(identifier))")
        layer.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
    }

    /// A Text row: its id once ST-4b gives it one, else the inspector's control labelled `label`.
    @MainActor private func row(_ design: Journey, _ row: (id: String, label: String)) -> XCUIElement {
        let byID = design.element(row.id)
        if byID.waitForExistence(timeout: 2) { return byID }
        return design.element("suite.inspector").descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", row.label)).firstMatch
    }

    /// The chip titled `title` in a ChoiceChips row: inside the row's id, else anywhere in the inspector.
    @MainActor private func chip(_ design: Journey, _ row: (id: String, label: String), _ title: String) -> XCUIElement {
        let group = design.element(row.id)
        if group.waitForExistence(timeout: 2) { return group.buttons[title].firstMatch }
        return design.element("suite.inspector").buttons[title].firstMatch
    }

    /// The committed text's frame in screen points: the inspector's X, Y, W and H, scaled to the canvas.
    @MainActor private func committedFrame(_ design: Journey) -> CGRect {
        let canvas = design.element("suite.canvas").frame
        let scale = Double(canvas.width) / Self.pageWidth
        let values = ["X position", "Y position", "Width", "Height"].map { frameValue(design, $0) ?? .nan }
        guard values.count == 4 else { return .null }
        return CGRect(x: Double(canvas.minX) + values[0] * scale, y: Double(canvas.minY) + values[1] * scale,
                      width: values[2] * scale, height: values[3] * scale)
    }

    /// The number a Frame field reads, from its spoken value ("1,440 points").
    @MainActor private func frameValue(_ design: Journey, _ name: String) -> Double? {
        let field = design.element("suite.inspector").descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "no \(name) field in the inspector")
        return Self.number(field)
    }

    /// Whether the status line's zoom reads 50% ("Zoom 50%" as a label, or "50%" as a plain Text's words).
    @MainActor private func statusReads50(_ design: Journey) -> Bool {
        let status = design.element("suite.status")
        let texts = status.staticTexts.allElementsBoundByIndex.flatMap { [$0.label, $0.value as? String ?? ""] }
        return texts.contains { $0 == "50%" || $0 == "Zoom 50%" }
    }

    /// The first number an element reads ("32", "32 pt", "1,440 points"), or nil.
    @MainActor private static func number(_ element: XCUIElement) -> Double? {
        guard let word = text(element).split(separator: " ").first else { return nil }
        return Double(word.filter { character in character.isNumber || character == "." || character == "-" })
    }

    /// What an element reads: its value where macOS puts a field's number or a menu's choice, else its label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }

    /// Whether `element`'s label reads `label` within `timeout` seconds.
    @MainActor private static func waitForLabel(_ element: XCUIElement, _ label: String, timeout: Double = 5) -> Bool {
        waitUntil(timeout: timeout) { element.exists && element.label == label }
    }

    /// Whether `condition` holds within `timeout` seconds.
    @MainActor private static func waitUntil(timeout: Double = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return condition()
    }
}
