// FlareJourneyTests+FillStroke.swift: J8 (inspector-timeline IT-5). On
// `-FlareSample bounce` it selects Ball, types FF3B30 into FILL's hex field
// (the stage's picture changes), types 4 into the stroke Width bar (it reads
// 4.0 pt), picks Round from the Cap and Join menus, then ⌘Z: Join reads its
// old choice again and Cap stays Round. The hex and Width fields are found
// inside their rows (`flare.inspector.fill`, `.strokeWidth`); a menu's items
// are the hittable ones, since AppKit keeps closed menus in the tree. Shots
// are `flare-j8-<step>`. A menu is clicked through its button (by id or the
// label Cap or Join), not the row's first match, which can be its label text.
import XCTest

final class FlareFillStrokeJourneys: XCTestCase {
    /// J8: fill, width, cap and join on Ball; one undo takes back only the join.
    @MainActor func testFillAndStroke() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. Select Ball from its timeline track: FILL and STROKE show.
        let ball = flare.element("flare.timeline").buttons.matching(
            NSPredicate(format: "label == 'Ball'")).firstMatch
        XCTAssert(ball.waitForExistence(timeout: 10), "no Ball track in the timeline")
        ball.click()
        let fill = flare.element("flare.inspector.fill")
        XCTAssert(fill.waitForExistence(timeout: 5), "selecting Ball showed no FILL row")
        flare.shot("j8-1-ball")

        // 2. Type FF3B30 into the fill's hex: it reads back, and the stage draws it.
        let stage = flare.element("suite.canvas")
        XCTAssert(stage.waitForExistence(timeout: 5), "no stage (suite.canvas)")
        let before = stage.screenshot().pngRepresentation
        let hex = fill.textFields.firstMatch
        XCTAssert(hex.waitForExistence(timeout: 5), "the FILL row has no hex field")
        replaceText(in: hex, with: "FF3B30", flare)
        flare.press(.return)
        XCTAssert(waitFor { ((hex.value as? String) ?? "").uppercased().contains("FF3B30") },
                  "the fill reads \(String(describing: hex.value)), not FF3B30")
        XCTAssert(waitFor { stage.screenshot().pngRepresentation != before }, "the stage looks the same after the fill")
        flare.shot("j8-2-fill")

        // 3. Type 4 into the Width bar: it reads 4.0 pt.
        let width = flare.element("flare.inspector.strokeWidth")
        XCTAssert(width.waitForExistence(timeout: 5), "no stroke Width bar")
        width.click()
        let field = width.textFields.firstMatch.waitForExistence(timeout: 3)
            ? width.textFields.firstMatch : flare.element("suite.inspector").textFields["Width"]
        XCTAssert(field.waitForExistence(timeout: 5), "clicking the Width bar opened no field")
        replaceText(in: field, with: "4", flare)
        flare.press(.return)
        XCTAssert(waitFor { self.number(width) == 4 }, "Width reads \(String(describing: width.value)), not 4.0 pt")
        flare.shot("j8-3-width")

        // 4. Cap Round, then Join Round; remember the join it had.
        let oldJoin = value(of: "flare.inspector.join", flare)
        choose("Round", in: "flare.inspector.cap", flare)
        expect("flare.inspector.cap", reads: "Round", flare)
        choose("Round", in: "flare.inspector.join", flare)
        expect("flare.inspector.join", reads: "Round", flare)
        flare.shot("j8-4-cap-join")

        // 5. ⌘Z takes back the join only.
        flare.press(character: "z", .command)
        expect("flare.inspector.join", reads: oldJoin, flare)
        expect("flare.inspector.cap", reads: "Round", flare)
        flare.shot("j8-5-undo-join")
    }

    /// Clears `field` and types `text`, without ⌘A (Edit > Select All has it).
    @MainActor private func replaceText(in field: XCUIElement, with text: String, _ flare: Journey) {
        field.click()
        flare.app.typeKey(.rightArrow, modifierFlags: .command)
        for _ in 0..<12 { flare.app.typeKey(.delete, modifierFlags: []) }
        flare.app.typeText(text)
    }

    /// The Cap or Join menu's button: under the inspector, a menu, pop-up or plain button with the row's id or its
    /// label ("Cap" for `flare.inspector.cap`). The id alone can match the row's "Cap" text first, and a click on
    /// that text opens nothing (#2237).
    @MainActor private func picker(_ id: String, _ flare: Journey) -> XCUIElement {
        let types = [XCUIElement.ElementType.menuButton, .popUpButton, .button].map { NSNumber(value: $0.rawValue) }
        let label = (id.split(separator: ".").last.map(String.init) ?? id).capitalized
        return flare.element("suite.inspector").descendants(matching: .any).matching(
            NSPredicate(format: "elementType IN %@ AND (identifier == %@ OR label == %@)", types, id, label)
        ).firstMatch
    }

    /// Opens the menu `id` and clicks its hittable item `title`.
    @MainActor private func choose(_ title: String, in id: String, _ flare: Journey) {
        let menu = picker(id, flare)
        XCTAssert(menu.waitForExistence(timeout: 5), "no \(id) menu")
        XCTAssert(menu.isEnabled, "the \(id) menu is disabled")
        menu.click()
        let items = flare.app.menuItems.matching(NSPredicate(format: "title == %@", title))
        var item: XCUIElement?
        for _ in 0..<15 where item == nil {
            item = items.allElementsBoundByIndex.first { $0.exists && $0.isHittable }
            if item == nil { Thread.sleep(forTimeInterval: 0.2) }
        }
        guard let item else { return XCTFail("clicking \(id) showed no \(title) item") }
        item.click()
    }

    /// The menu `id`'s value: the title of its choice, from the row (its accessibility value) or else its button.
    @MainActor private func value(of id: String, _ flare: Journey) -> String {
        let row = flare.element(id)
        XCTAssert(row.waitForExistence(timeout: 5), "no \(id) menu")
        let shown = (row.value as? String) ?? ""
        return shown.isEmpty ? (picker(id, flare).value as? String) ?? "" : shown
    }

    /// The menu `id` reads `title` within five seconds: some element with that id carries it as its value.
    @MainActor private func expect(_ id: String, reads title: String, _ flare: Journey) {
        let reading = flare.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ AND value == %@", id, title)).firstMatch
        XCTAssert(waitFor { reading.exists || self.value(of: id, flare) == title },
                  "\(id) reads \(value(of: id, flare)), not \(title)")
    }

    /// A bar's value: a number, or the first number in its text ("4.0 pt"); nil with neither.
    @MainActor private func number(_ bar: XCUIElement) -> Double? {
        if let number = bar.value as? NSNumber { return number.doubleValue }
        let text = (bar.value as? String) ?? ""
        return text.range(of: #"-?[0-9]+(\.[0-9]+)?"#, options: .regularExpression).flatMap { Double(text[$0]) }
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }
}
