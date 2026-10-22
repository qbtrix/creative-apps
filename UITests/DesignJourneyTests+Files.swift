// DesignJourneyTests+Files.swift: J13 and J14, undo in text fields, the save
// state and closing with unsaved changes (files-history, FH-5;
// docs/blueprints/design/features/files-history.md, Journeys 1 and 2; #275,
// #270). Live services, on `-DesignFixture cards` at 1024 × 768.
// J13 runs with `-DesignSaveTo <tmp>`, so Save writes there with no panel. It
// first gives the document a step to undo: A's X typed to 150 with Return,
// then ⌘S, so the status line's save state (`design.status.save`) reads
// "Saved". Then it clicks X again, types 345 and presses ⌘Z inside the field:
// the field's own undo takes the typing back, so the field reads 150 again,
// and the document is untouched: the top bar's Undo (`design.bar.undo`) keeps
// its name and the state still reads "Saved" (a ⌘Z sent to the document would
// undo the X step and read "Edited"). Escape closes the field, and Edit >
// Undo then names the document's step. Drawing a rectangle reads "Edited";
// ⌘S reads "Saved" with no save panel, and the file is on disk. (The window's
// edited dot waits on a SuiteUI modifier, #2861; until then "Edited" is the
// state shown.) J14 draws on `cards` and presses ⌘W: the close prompt, an
// NSAlert sheet (SuiteUI's unsaved guard), names "Untitled", the fixture's name;
// Cancel (`design.close.cancel`) keeps the window; ⌘W again and Don't Save
// (`design.close.dontSave`) closes it. A fresh, clean `cards` window closes
// on ⌘W with no alert.
import XCTest

final class DesignFilesJourneyTests: XCTestCase {
    /// The services this journey runs on.
    private static let services = "live"
    static let arguments = ["-DesignServices", services, "-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// Desktop's row (collapsed when the file opens) and A's inside it (DesignFixtures.cards).
    static let desktopRow = "design.layer.node-1", rowA = "design.layer.node-2"
    static let xBar = "design.inspector.x", saveState = "design.status.save", undoID = "design.bar.undo"
    static let cancelID = "design.close.cancel", dontSaveID = "design.close.dontSave"

    /// J13: ⌘Z in the X field undoes its typing, not the document; a draw reads Edited, ⌘S Saved, no panel.
    @MainActor func testUndoInTextFieldsAndDirtyState() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "design-files-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "cards.design")
        let design = launch(Self.arguments + ["-DesignSaveTo", file.path])
        let undo = design.element(Self.undoID)
        XCTAssertNotEqual(state(design), "Edited", "the fixture opened reading Edited")

        // 1. A's X typed to 150 with Return: a document step; ⌘S: Saved.
        design.expandDesignLayer(Self.desktopRow)
        design.clickDesignLayer(Self.rowA)
        let opened = undo.label
        let bar = design.element("suite.inspector").descendants(matching: .any)[Self.xBar].firstMatch
        XCTAssert(bar.waitForExistence(timeout: 5), "no X bar in the inspector (\(Self.xBar))")
        bar.click()
        var field = typingField(design, in: bar)
        XCTAssert(field.waitForExistence(timeout: 5), "clicking X opened no typing field")
        design.press(character: "a", .command)
        field.typeText("150")
        design.press(.return)
        XCTAssert(Self.waitUntil { undo.label != opened }, "typing X 150 made no document step (Undo reads \(undo.label))")
        let step = undo.label
        design.press(character: "s", .command)
        XCTAssert(Self.waitUntil { self.state(design) == "Saved" }, "⌘S left the state at \(state(design))")
        expectNoPanel(design, after: "the first ⌘S")
        design.shot("files-x-saved")

        // 2. X again: type 345, ⌘Z in the field: the typing goes, the document keeps its step and stays Saved.
        bar.click()
        field = typingField(design, in: bar)
        XCTAssert(field.waitForExistence(timeout: 5), "clicking X again opened no typing field")
        let before = Self.text(field)
        design.press(character: "a", .command)
        field.typeText("345")
        XCTAssert(Self.waitUntil { Self.text(field).contains("345") }, "the X field reads \(Self.text(field)), not 345")
        design.shot("files-x-typed")
        design.press(character: "z", .command)
        XCTAssert(Self.waitUntil { !Self.text(field).contains("345") }, "⌘Z in the X field left \(Self.text(field))")
        XCTAssertEqual(Self.text(field), before, "⌘Z in the X field didn't put its text back")
        XCTAssertEqual(undo.label, step, "⌘Z in the X field changed the document's Undo (\(step) to \(undo.label))")
        XCTAssertEqual(state(design), "Saved", "⌘Z in the X field reached the document")
        design.shot("files-x-undone")

        // 3. Escape: the field closes and Edit > Undo names the document's step again.
        design.press(.escape)
        XCTAssertEqual(editMenuUndo(design), step, "Edit > Undo doesn't name the document's step after Escape")
        XCTAssertEqual(undo.label, step, "Escape changed the document's Undo")

        // 4. A rectangle drawn: Edited; ⌘S: Saved, with no panel, and the file is written.
        let rectangle = design.element("suite.tools").buttons["Rectangle"]
        XCTAssert(rectangle.waitForExistence(timeout: 5), "no Rectangle in the tool box (suite.tools)")
        rectangle.click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.56, dy: 0.61), to: CGVector(dx: 0.70, dy: 0.75))
        XCTAssert(Self.waitUntil { undo.label == "Undo Add Rectangle" }, "drawing made no Add Rectangle step (Undo reads \(undo.label))")
        XCTAssert(Self.waitUntil { self.state(design) == "Edited" }, "a draw left the state at \(state(design)), not Edited")
        design.shot("files-edited")
        design.press(character: "s", .command)
        XCTAssert(Self.waitUntil { self.state(design) == "Saved" }, "⌘S left the state at \(state(design)), not Saved")
        expectNoPanel(design, after: "⌘S")
        XCTAssert(FileManager.default.fileExists(atPath: file.path), "⌘S wrote no file at -DesignSaveTo")
        design.shot("files-saved")
    }

    /// J14: an edited window asks before closing, Cancel keeps it, Don't Save closes it; a clean one just closes.
    @MainActor func testCloseWithUnsavedChanges() {
        let design = launch(Self.arguments)
        let canvas = design.element("suite.canvas")
        let rectangle = design.element("suite.tools").buttons["Rectangle"]
        XCTAssert(rectangle.waitForExistence(timeout: 5), "no Rectangle in the tool box (suite.tools)")
        rectangle.click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.56, dy: 0.61), to: CGVector(dx: 0.70, dy: 0.75))
        let undo = design.element(Self.undoID)
        XCTAssert(Self.waitUntil { undo.label == "Undo Add Rectangle" }, "drawing made no Add Rectangle step (Undo reads \(undo.label))")

        // 1. ⌘W: the prompt names Untitled; Cancel keeps the window.
        design.press(character: "w", .command)
        var alert = closeAlert(design)
        XCTAssert(alert.exists, "⌘W on an edited window showed no alert")
        let message = "Do you want to save the changes made to the document “Untitled”?"
        let title = alert.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", message, message)).firstMatch
        XCTAssert(title.waitForExistence(timeout: 5), "the close alert doesn't read \(message)")
        design.shot("files-close-prompt")
        alert.buttons[Self.cancelID].click()
        XCTAssert(alert.waitForNonExistence(timeout: 5), "Cancel left the close alert up")
        XCTAssert(canvas.waitForExistence(timeout: 5), "Cancel closed the window")
        XCTAssertEqual(undo.label, "Undo Add Rectangle", "Cancel changed the document")
        design.shot("files-close-cancelled")

        // 2. ⌘W again, Don't Save: the window closes.
        design.press(character: "w", .command)
        alert = closeAlert(design)
        XCTAssert(alert.exists, "the second ⌘W showed no alert")
        alert.buttons[Self.dontSaveID].click()
        XCTAssert(canvas.waitForNonExistence(timeout: 10), "Don't Save left the window open")
        design.app.terminate()

        // 3. A clean window: ⌘W closes it with no alert.
        let clean = launch(Self.arguments)
        let cleanCanvas = clean.element("suite.canvas")
        clean.press(character: "w", .command)
        XCTAssert(cleanCanvas.waitForNonExistence(timeout: 10), "⌘W left a clean window open")
        XCTAssertFalse(clean.app.sheets.firstMatch.exists || clean.app.dialogs.firstMatch.exists, "a clean window asked before closing")
        clean.app.terminate()
    }

    /// Design launched with `arguments`, its canvas up.
    @MainActor private func launch(_ arguments: [String]) -> Journey {
        let design = Journey("Design", self, arguments: arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "the cards fixture showed no page (suite.canvas)")
        return design
    }

    /// The close prompt: a sheet on the window, else a dialog.
    @MainActor private func closeAlert(_ design: Journey) -> XCUIElement {
        let sheet = design.app.sheets.firstMatch
        if sheet.waitForExistence(timeout: 5) { return sheet }
        let dialog = design.app.dialogs.firstMatch
        _ = dialog.waitForExistence(timeout: 2)
        return dialog
    }

    /// No Save panel (a sheet or a dialog) came up after `action`.
    @MainActor private func expectNoPanel(_ design: Journey, after action: String) {
        XCTAssertFalse(design.app.sheets.firstMatch.waitForExistence(timeout: 1), "\(action) opened a panel")
        XCTAssertFalse(design.app.dialogs.firstMatch.exists, "\(action) opened a dialog")
    }

    /// The status line's save state ("Saved", "Edited"), or "" when none shows.
    @MainActor private func state(_ design: Journey) -> String {
        let label = design.element(Self.saveState)
        return label.exists ? Self.text(label) : ""
    }

    /// Edit > Undo's title, read from the open menu, which then closes.
    @MainActor private func editMenuUndo(_ design: Journey) -> String {
        let edit = design.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let item = edit.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", "Undo")).firstMatch
        let title = item.waitForExistence(timeout: 3) ? item.title : ""
        design.press(.escape)
        return title
    }

    /// The typing field a clicked bar opens: inside the bar, else the inspector's only one.
    @MainActor private func typingField(_ design: Journey, in bar: XCUIElement) -> XCUIElement {
        let inside = bar.textFields.firstMatch
        if inside.waitForExistence(timeout: 2) { return inside }
        return design.element("suite.inspector").textFields.firstMatch
    }

    /// What an element reads: its value, else its label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        if let number = element.value as? NSNumber { return number.stringValue }
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
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
