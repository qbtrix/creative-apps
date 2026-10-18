// DesignJourneyTests+Arrange.swift: J7, J8 and J9, duplicate, cut, copy and
// paste, and group (packet docs/blueprints/design/features/copy-group.md,
// Journey steps, CG-a, C-5). On `cards` at 1024 × 768, live services.
// J7: with nothing selected Edit > Duplicate is off; A pressed on the page and
// ⌘D gives "Undo Duplicate"; an Option-drag of the selected copy 100 pt down
// is one more "Duplicate" step, so Layers shows A three times and one ⌘Z
// leaves two (a copy step and a move step would leave three); ⌘D on Locked
// makes an unlocked copy. J8: Pair copied and pasted from Layers lands in
// Desktop with its two children ("Undo Paste"); B cut ("Undo Cut") is pasted
// into a new file after a relaunch on `empty`; ⌘V in the inspector's X field,
// before and after ⌘A ⌘C there, adds no layer; with only plain text on the
// pasteboard Edit > Paste is off. J9: A and B Shift-selected, ⌘G gives
// "Undo Group" and a "Group 1" row, ⇧⌘G "Undo Ungroup", the row gone and its
// two children selected; A plus E1 (inside Pair) leaves Object > Group off.
// Presses on the page go to `suite.canvas.artboard`, the page's rectangle, at
// page points over the page's 1440 × 1024 size. Menu tooltips (the refusal
// text) are not readable by XCUI; DesignWindowTests prove those.
import AppKit
import XCTest

final class DesignArrangeJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// Rows in Layers (DesignFixtures.cards and .empty).
    static let desktopRow = "design.layer.node-1", pairRow = "design.layer.node-6"
    static let e1Row = "design.layer.node-7", lockedRow = "design.layer.node-9"
    static let xBar = "design.inspector.x", selection = "design.status.selection"

    /// J7: ⌘D and an Option-drag each one "Duplicate" step; a locked layer's copy is unlocked.
    @MainActor func testDuplicateAndOptionDrag() {
        let design = launch(Self.arguments)
        let undo = design.element("design.bar.undo")

        // 1. Nothing selected: Edit > Duplicate is off.
        let edit = design.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let duplicate = edit.menuItems["Duplicate"]
        XCTAssert(duplicate.waitForExistence(timeout: 3), "the Edit menu shows no Duplicate")
        XCTAssertFalse(duplicate.isEnabled, "Edit > Duplicate is on with nothing selected")
        design.shot("arrange-duplicate-off", screen: true)
        design.press(.escape)

        // 2. A pressed on the page, then ⌘D: one Duplicate step and a second A.
        click(design, x: 150, y: 140)
        design.press(character: "d", .command)
        XCTAssert(Self.waitForLabel(undo, "Undo Duplicate"), "⌘D made no step (Undo reads \(undo.label))")
        XCTAssert(Self.waitUntil { self.rows(design, "A") == 2 }, "⌘D left \(rows(design, "A")) A rows, not 2")
        design.shot("arrange-duplicate")

        // 3. The selected copy (at 110, 110) Option-dragged 100 pt down: one more Duplicate step.
        let page = artboard(design)
        let start = page.coordinate(withNormalizedOffset: Self.offset(160, 150))
        XCUIElement.perform(withKeyModifiers: .option) {
            start.press(forDuration: 0.2, thenDragTo: page.coordinate(withNormalizedOffset: Self.offset(160, 250)))
        }
        XCTAssert(Self.waitForLabel(undo, "Undo Duplicate"), "the Option-drag made no Duplicate step (Undo reads \(undo.label))")
        XCTAssert(Self.waitUntil { self.rows(design, "A") == 3 }, "the Option-drag left \(rows(design, "A")) A rows, not 3")
        design.shot("arrange-option-drag")

        // 4. One ⌘Z takes the whole Option-drag back: two steps would leave the third A.
        design.press(character: "z", .command)
        XCTAssert(Self.waitUntil { self.rows(design, "A") == 2 }, "one Undo left \(rows(design, "A")) A rows: the Option-drag was two steps")
        design.press(character: "z", [.command, .shift])
        XCTAssert(Self.waitUntil { self.rows(design, "A") == 3 }, "Redo left \(rows(design, "A")) A rows, not 3")

        // 5. Locked selected from Layers, then ⌘D: the copy is unlocked.
        clickRow(design, Self.lockedRow, "Locked")
        design.press(character: "d", .command)
        XCTAssert(Self.waitUntil { self.rows(design, "Locked") == 2 }, "⌘D on Locked left \(rows(design, "Locked")) Locked rows")
        XCTAssertEqual(lockToggles(design, "Locked"), ["Lock Layer", "Unlock Layer"], "the copy of Locked is not unlocked")
        design.shot("arrange-duplicate-locked")
    }

    /// J8: copy and paste in place, cut into another file, the X field's own paste, and Paste off for text.
    @MainActor func testCutCopyPasteAcrossFiles() {
        var design = launch(Self.arguments)
        let undo = design.element("design.bar.undo")

        // 1. Pair selected from Layers (a press on A first opens Desktop), ⌘C, ⌘V: a second Pair.
        click(design, x: 150, y: 140)
        clickRow(design, Self.pairRow, "Pair")
        design.press(character: "c", .command)
        design.press(character: "v", .command)
        XCTAssert(Self.waitForLabel(undo, "Undo Paste"), "⌘V made no Paste step (Undo reads \(undo.label))")
        XCTAssert(Self.waitUntil { self.rows(design, "Pair") == 2 }, "⌘V left \(rows(design, "Pair")) Pair rows, not 2")

        // 2. The pasted Pair sits 10, 10 down and right, on top: a press at E1's copy opens it on its two children.
        click(design, x: 960, y: 460)
        XCTAssert(Self.waitUntil { self.rows(design, "E1") >= 1 && self.rows(design, "E2") >= 1 }, "the pasted Pair shows no E1 and E2 rows")
        design.shot("arrange-paste")

        // 3. B pressed on the page, ⌘X: one Cut step and B gone.
        click(design, x: 400, y: 180)
        design.press(character: "x", .command)
        XCTAssert(Self.waitForLabel(undo, "Undo Cut"), "⌘X made no Cut step (Undo reads \(undo.label))")
        XCTAssert(Self.waitUntil { self.rows(design, "B") == 0 }, "⌘X left a B row")
        design.shot("arrange-cut")

        // 4. A new file after a relaunch: Desktop selected, ⌘V pastes B (the pasteboard outlived the app).
        design = launch(["-DesignFixture", "empty", "-SuiteWindowSize", "1024x768"])
        let newUndo = design.element("design.bar.undo")
        clickRow(design, Self.desktopRow, "Desktop")
        design.press(character: "v", .command)
        XCTAssert(Self.waitForLabel(newUndo, "Undo Paste"), "⌘V in the new file made no step (Undo reads \(newUndo.label))")
        XCTAssert(Self.waitUntil { self.rows(design, "B") == 1 }, "the new file holds \(rows(design, "B")) B rows, not 1")
        design.shot("arrange-paste-other-file")

        // 5. The pasted B's X field: ⌘V there, then ⌘A ⌘C ⌘V and Return, act on its text, never on layers.
        let count = rows(design)
        let bar = design.element("suite.inspector").descendants(matching: .any)[Self.xBar].firstMatch
        XCTAssert(bar.waitForExistence(timeout: 5), "no X bar in the inspector (\(Self.xBar))")
        bar.click()
        let field = typingField(design, in: bar)
        XCTAssert(field.waitForExistence(timeout: 5), "clicking X opened no typing field")
        design.press(character: "v", .command)
        design.press(character: "a", .command)
        design.press(character: "c", .command)
        design.press(character: "v", .command)
        design.press(.return)
        XCTAssertFalse(Self.waitUntil(timeout: 2) { self.rows(design) != count }, "⌘V in the X field changed the layers (\(rows(design)) rows, was \(count))")
        design.shot("arrange-x-field-paste")

        // 6. Only plain text on the pasteboard: Edit > Paste with the canvas focused is off.
        _ = NSPasteboard.general.clearContents()
        XCTAssert(NSPasteboard.general.setString("plain text", forType: .string), "could not put plain text on the pasteboard")
        click(design, x: 720, y: 900)
        let edit = design.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let paste = edit.menuItems["Paste"]
        XCTAssert(paste.waitForExistence(timeout: 3), "the Edit menu shows no Paste")
        XCTAssertFalse(paste.isEnabled, "Edit > Paste is on with only plain text on the pasteboard")
        design.shot("arrange-paste-off", screen: true)
        design.press(.escape)
    }

    /// J9: A and B grouped and ungrouped, one step each; layers of two parents can't be grouped.
    @MainActor func testGroupAndUngroup() {
        let design = launch(Self.arguments)
        let undo = design.element("design.bar.undo"), status = design.element(Self.selection)

        // 1. A pressed, B Shift-pressed: two layers selected.
        click(design, x: 150, y: 140)
        click(design, x: 400, y: 180, modifiers: .shift)
        XCTAssert(Self.waitForText(status, "2 Layers"), "Shift-press selected \(Self.text(status)), not 2 Layers")

        // 2. ⌘G: one Group step and a Group 1 row.
        design.press(character: "g", .command)
        XCTAssert(Self.waitForLabel(undo, "Undo Group"), "⌘G made no Group step (Undo reads \(undo.label))")
        XCTAssert(Self.waitUntil { self.rows(design, "Group 1") == 1 }, "⌘G showed no Group 1 row")
        design.shot("arrange-group")

        // 3. ⇧⌘G: one Ungroup step, the row gone, its two children selected.
        design.press(character: "g", [.command, .shift])
        XCTAssert(Self.waitForLabel(undo, "Undo Ungroup"), "⇧⌘G made no Ungroup step (Undo reads \(undo.label))")
        XCTAssert(Self.waitUntil { self.rows(design, "Group 1") == 0 }, "⇧⌘G left the Group 1 row")
        XCTAssert(Self.waitForText(status, "2 Layers"), "Ungroup selected \(Self.text(status)), not its 2 layers")
        design.shot("arrange-ungroup")

        // 4. E1 pressed (opens Pair in Layers), A pressed, E1's row Shift-clicked: Group is off.
        click(design, x: 950, y: 450)
        click(design, x: 150, y: 140)
        let e1 = design.element("suite.sidebar").descendants(matching: .any)[Self.e1Row].firstMatch
        XCTAssert(e1.waitForExistence(timeout: 5), "no E1 row in Layers (\(Self.e1Row))")
        XCUIElement.perform(withKeyModifiers: .shift) { e1.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click() }
        XCTAssert(Self.waitForText(status, "2 Layers"), "Shift-click on E1 selected \(Self.text(status)), not 2 Layers")
        let object = design.app.menuBars.firstMatch.menuBarItems["Object"]
        object.click()
        let group = object.menuItems["Group"]
        XCTAssert(group.waitForExistence(timeout: 3), "the Object menu shows no Group")
        XCTAssertFalse(group.isEnabled, "Object > Group is on for A and E1, which have different parents")
        design.shot("arrange-group-off", screen: true)
        design.press(.escape)
    }

    // MARK: Helpers

    /// Launches Design with `arguments` and waits for its page.
    @MainActor private func launch(_ arguments: [String]) -> Journey {
        let design = Journey("Design", self, arguments: arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "the fixture showed no page (suite.canvas)")
        return design
    }

    /// The page's rectangle on the canvas.
    @MainActor private func artboard(_ design: Journey) -> XCUIElement {
        let page = design.element("suite.canvas.artboard")
        XCTAssert(page.waitForExistence(timeout: 5), "no page on the canvas (suite.canvas.artboard)")
        return page
    }

    /// Clicks the page at page point (`x`, `y`), holding `modifiers`.
    @MainActor private func click(_ design: Journey, x: Double, y: Double, modifiers: XCUIElement.KeyModifierFlags = []) {
        let point = artboard(design).coordinate(withNormalizedOffset: Self.offset(x, y))
        XCUIElement.perform(withKeyModifiers: modifiers) { point.click() }
    }

    /// A page point as a fraction of the 1440 × 1024 page.
    private static func offset(_ x: Double, _ y: Double) -> CGVector {
        CGVector(dx: x / 1440, dy: y / 1024)
    }

    /// Clicks the Layers row `identifier`, inside its label.
    @MainActor private func clickRow(_ design: Journey, _ identifier: String, _ name: String) {
        let layer = design.element("suite.sidebar").descendants(matching: .any)[identifier].firstMatch
        XCTAssert(layer.waitForExistence(timeout: 5), "no \(name) row in Layers (\(identifier))")
        layer.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
    }

    /// The Layers rows showing now, every one or only those named `name`.
    @MainActor private func layerRows(_ design: Journey, _ name: String? = nil) -> [XCUIElement] {
        let all = design.element("suite.sidebar").descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'design.layer.'")).allElementsBoundByIndex
        guard let name else { return all }
        return all.filter { row in
            row.label == name || row.label.hasPrefix(name + ",") || row.label.hasPrefix(name + " ")
                || row.staticTexts[name].exists
        }
    }

    /// How many Layers rows show now, every one or only those named `name`.
    @MainActor private func rows(_ design: Journey, _ name: String? = nil) -> Int {
        layerRows(design, name).count
    }

    /// The lock toggles' labels on the rows named `name`, sorted: "Unlock Layer" for a locked one.
    @MainActor private func lockToggles(_ design: Journey, _ name: String) -> [String] {
        layerRows(design, name).compactMap { row in
            let toggle = row.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier ENDSWITH '.locked'")).firstMatch
            return toggle.exists ? toggle.label : nil
        }.sorted()
    }

    /// The typing field a clicked bar opens: inside the bar, else the inspector's only one.
    @MainActor private func typingField(_ design: Journey, in bar: XCUIElement) -> XCUIElement {
        let inside = bar.textFields.firstMatch
        if inside.waitForExistence(timeout: 2) { return inside }
        return design.element("suite.inspector").textFields.firstMatch
    }

    /// Whether `element`'s label reads `label` within `timeout` seconds.
    @MainActor private static func waitForLabel(_ element: XCUIElement, _ label: String, timeout: Double = 5) -> Bool {
        waitUntil(timeout: timeout) { element.exists && element.label == label }
    }

    /// What an element reads: its value where macOS puts a text's string, else its label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }

    /// Whether `element` reads `text` within `timeout` seconds.
    @MainActor private static func waitForText(_ element: XCUIElement, _ text: String, timeout: Double = 5) -> Bool {
        waitUntil(timeout: timeout) { element.exists && Self.text(element) == text }
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
