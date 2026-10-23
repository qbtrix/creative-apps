// PhotoJourneyTests+MultiSelect.swift: PJ-M1, several layers picked and
// acted on at once (multi-layer-select PM-8 written, turned on in PM-z;
// docs/blueprints/photo/features/multi-layer-select.md, Journey steps 1-7).
// On `-PhotoFixture layered` (Paint, Curves 1, Background, top first; Paint
// selected) Command-J first duplicates Paint, so the list holds the packet's
// four rows: Paint copy, Paint, Curves 1, Background. Then: click row 1,
// Shift-click row 3 (rows 1-3 picked, the inspector on row 3's Curves 1, the
// primary); Command-click row 2 off; row 1's eye hides rows 1 and 3 in one
// "Hide Layers" step; the Opacity slider to 50 sets both, one "Layer Opacity"
// step; the Move tool drags the canvas 40 px right, one "Move Layers" step
// that Command-Z takes back; Option-Command-A (Select > All Layers) picks all
// four; Delete Layer is refused with "At least one layer must stay."; row 4
// Command-clicked off, Delete Layers takes three in one step and Command-Z
// brings them back. Rows are `photo.layer.row.<id>` (PM-3), picked while
// selected; the eye is `photo.layer.<id>.eye`, labelled "Hide <name>" or
// "Show <name>". Undo steps are read from the window toolbar's Undo button,
// as PhotoLayerOpsJourneyTests does. Step 8 (Group Layers) is PM-g's
// testGroupLayers, not written here. Shots: `photo-multi-*`.
import XCTest

final class PhotoMultiLayerJourneyTests: XCTestCase {
    private static let rowPrefix = "photo.layer.row."

    /// PJ-M1: pick a range, toggle one off, hide, fade and move the pick, select all, delete all but one.
    @MainActor func testSelectSeveralLayers() throws {
        let photo = Journey("Photo", self, arguments: photoArguments(fixture: "layered"))
        XCTAssert(photo.element("photo.status.preview").waitForExistence(timeout: 30), "-PhotoFixture layered shows no Preview data pill")
        let list = photo.element("suite.sidebar").descendants(matching: .any)["photo.layers"]
        XCTAssert(list.waitForExistence(timeout: 5), "the sidebar has no layer list (photo.layers)")
        photo.press(character: "j", .command)
        expect("Undo Duplicate Layer", photo, "Command-J made no Duplicate Layer step")
        XCTAssert(waitUntil { self.rowIDs(photo).count == 4 }, "the list shows \(rowIDs(photo).count) rows, not four")
        let ids = rowIDs(photo)
        guard ids.count == 4 else { return }
        let rows = ids.map { photo.element(Self.rowPrefix + $0) }
        photo.shot("multi-opened")

        // 1. Click row 1, Shift-click row 3: rows 1 to 3 picked, the inspector on row 3's Curves 1.
        click(rows[0])
        XCUIElement.perform(withKeyModifiers: .shift) { click(rows[2]) }
        expectPicked([0, 1, 2], rows, "Shift-click on row 3 didn't pick rows 1 to 3")
        XCTAssert(photo.element("photo.curves").waitForExistence(timeout: 5), "the inspector isn't on row 3's Curves 1, the primary")
        photo.shot("multi-1-range")

        // 2. Command-click row 2: rows 1 and 3 stay picked.
        XCUIElement.perform(withKeyModifiers: .command) { click(rows[1]) }
        expectPicked([0, 2], rows, "Command-click on row 2 didn't take it off the pick")
        photo.shot("multi-2-toggle")

        // 3. Row 1's eye: rows 1 and 3 hide in one Hide Layers step.
        let eyes = ids.map { photo.element("photo.layer.\($0).eye") }
        XCTAssert(eyes[0].waitForExistence(timeout: 5), "row 1 has no eye (photo.layer.<id>.eye)")
        eyes[0].click()
        expect("Undo Hide Layers", photo, "row 1's eye made no Hide Layers step")
        XCTAssert(
            waitUntil { eyes[0].label.hasPrefix("Show") && eyes[2].label.hasPrefix("Show") },
            "rows 1 and 3 aren't both hidden (eyes read \(eyes[0].label), \(eyes[2].label))")
        XCTAssert(eyes[1].label.hasPrefix("Hide") && eyes[3].label.hasPrefix("Hide"), "the eye hid an unpicked row")
        photo.shot("multi-3-hidden")

        // 4. The Opacity slider to 50%: both picked rows read 50%, one Layer Opacity step.
        let opacity = photo.element("suite.inspector").sliders.matching(
            NSPredicate(format: "identifier == %@ OR label == %@", "photo.layer.opacity", "Opacity")).firstMatch
        XCTAssert(opacity.waitForExistence(timeout: 5), "no Opacity slider in the inspector (photo.layer.opacity)")
        opacity.adjust(toNormalizedSliderPosition: 0.5)
        expect("Undo Layer Opacity", photo, "the Opacity slider made no Layer Opacity step")
        XCTAssert(
            waitUntil { self.reads("50%", rows[0]) && self.reads("50%", rows[2]) },
            "rows 1 and 3 don't both read 50%")
        photo.shot("multi-4-opacity")

        // 5. Move tool, the canvas dragged 40 px right: one Move Layers step; Command-Z puts both back.
        photo.element("suite.tools").buttons["Move"].click()
        let canvas = photo.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        let before = canvas.screenshot().pngRepresentation
        let grab = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grab.press(forDuration: 0.1, thenDragTo: grab.withOffset(CGVector(dx: 40, dy: 0)))
        expect("Undo Move Layers", photo, "the Move drag made no Move Layers step")
        XCTAssert(waitUntil { canvas.screenshot().pngRepresentation != before }, "the Move drag didn't change the canvas")
        photo.shot("multi-5-moved")
        photo.press(character: "z", .command)
        expect("Redo Move Layers", photo, "Command-Z didn't take the Move Layers step back")
        photo.shot("multi-5-move-undone")

        // 6. Option-Command-A (Select > All Layers): all four rows picked.
        photo.press(character: "a", [.command, .option])
        expectPicked([0, 1, 2, 3], rows, "Option-Command-A didn't pick all four rows")
        photo.shot("multi-6-all-layers")

        // 7. Delete Layer refused; row 4 off, Delete Layers takes three in one step; Command-Z brings them back.
        let delete = photo.element("photo.layer.delete")
        XCTAssert(delete.waitForExistence(timeout: 5), "no Delete Layer (photo.layer.delete)")
        expectRefusal("At least one layer must stay.", on: delete, photo)
        XCTAssertEqual(rowIDs(photo).count, 4, "the refused Delete Layer removed a row")
        photo.shot("multi-7-refused")
        XCUIElement.perform(withKeyModifiers: .command) { click(rows[3]) }
        expectPicked([0, 1, 2], rows, "Command-click on row 4 didn't take it off the pick")
        delete.click()
        expect("Undo Delete Layers", photo, "Delete Layers made no one step")
        XCTAssert(waitUntil { self.rowIDs(photo) == [ids[3]] }, "Delete Layers left \(rowIDs(photo)), not row 4 alone")
        photo.shot("multi-7-deleted")
        photo.press(character: "z", .command)
        XCTAssert(waitUntil { self.rowIDs(photo) == ids }, "Command-Z didn't bring the three layers back (\(rowIDs(photo)))")
        photo.shot("multi-7-delete-undone")
    }

    // MARK: - Steps

    /// Clicks a row left of its middle, on its name, clear of the eye at its right end.
    @MainActor private func click(_ row: XCUIElement) {
        XCTAssert(row.waitForExistence(timeout: 5), "no row \(row.identifier)")
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)).click()
    }

    /// The layer ids of the list's rows, top first.
    @MainActor private func rowIDs(_ photo: Journey) -> [String] {
        let rows = photo.app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", Self.rowPrefix)).allElementsBoundByIndex
            .map { ($0.identifier, $0.frame.minY) }.sorted { $0.1 < $1.1 }
        var seen = Set<String>()
        return rows.map { String($0.0.dropFirst(Self.rowPrefix.count)) }.filter { seen.insert($0).inserted }
    }

    /// Exactly the rows at `picked` (0 is the top row) draw picked.
    @MainActor private func expectPicked(_ picked: Set<Int>, _ rows: [XCUIElement], _ message: String) {
        let matches = waitUntil { rows.indices.allSatisfy { rows[$0].isSelected == picked.contains($0) } }
        let shown = rows.indices.filter { rows[$0].isSelected }.map { $0 + 1 }
        XCTAssert(matches, "\(message) (picked rows: \(shown))")
    }

    /// Whether a text in `row` holds `text`, as its caption's "Multiply 50%".
    @MainActor private func reads(_ text: String, _ row: XCUIElement) -> Bool {
        row.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch.exists
    }

    /// `button` refuses with `reason`: clicked while enabled, the window says
    /// it; disabled, its help tag does when hovered.
    @MainActor private func expectRefusal(_ reason: String, on button: XCUIElement, _ photo: Journey) {
        if button.isEnabled { button.click() } else { button.hover() }
        let said = photo.app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@ OR title CONTAINS %@", reason, reason, reason))
            .firstMatch
        XCTAssert(said.waitForExistence(timeout: 5), "Delete Layer with every layer picked doesn't say \(reason)")
    }

    /// Waits for the button titled `title`, such as the window toolbar's "Undo Hide Layers".
    @MainActor private func expect(_ title: String, _ photo: Journey, _ message: String) {
        XCTAssert(photo.app.buttons[title].waitForExistence(timeout: 5), "\(message) (no \(title) button)")
    }

    /// Whether `condition` holds within five seconds.
    @MainActor private func waitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<10 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return condition()
    }
}
