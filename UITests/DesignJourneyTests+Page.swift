// DesignJourneyTests+Page.swift: CB-c, the page's size and the layers past
// its edge (packet docs/blueprints/design/features/canvas-basics.md, Journey
// steps 4; job RJ-D32). On `-DesignFixture cards` at 1024 × 768 it clicks the
// page's row in Pages and finds the inspector's Width 1440 and Height 1024
// (`design.inspector.page-width`, `design.inspector.page-height`), clicks
// Width, types 800 over the value the click selected and clicks the page's row
// to commit, as a mouse user does: the status line reads "800 × 1024 pt" and
// the toolbar's Undo (`design.bar.undo`) reads "Undo Change Page Size". It
// shoots the canvas, where Desktop's part past 800 still shows, dimmed (the
// shot is attached; the pixels are CB-9's snapshot). Then Height the same way
// to 768: "800 × 768 pt", one more step. Undo puts Height back at 1024, a
// second Undo Width at 1440. Every step uses the mouse on visible controls but
// the typed numbers: no Command-A and no Return, so the journey fails if a
// ScrubField stops selecting its value on open or committing on focus loss.
// A ScrubField reads its number as its value, spoken with its unit, and a
// plain Text its words as its value, so both are read by label or value.
// DJ-DS (document-setup DS-design): File > New opens the suite's New Document
// sheet on Design's frame presets; Story and Create make one page of 1080 × 1920.
import XCTest

final class DesignPageJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]

    /// CB-c: Width and Height in the inspector, one undo step each, Desktop dimmed past the page.
    @MainActor func testPageSizeAndPastThePage() throws {
        try walkPageSize()
    }

    /// DJ-DS: File > New, the Story preset, Create: the new file's one page is 1080 × 1920.
    @MainActor func testNewDocumentFromPreset() throws {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "the cards fixture showed no page")

        // 1. File > New File: the New Document sheet opens on Design's presets.
        let file = design.app.menuBars.firstMatch.menuBarItems["File"]
        file.click()
        let new = file.menuItems["New File"]
        XCTAssert(new.waitForExistence(timeout: 3), "the File menu shows no New File")
        new.click()
        XCTAssert(design.element("suite.newdoc").waitForExistence(timeout: 5), "File > New File opened no New Document sheet")
        design.shot("new-document-sheet")

        // 2. Pick Story: the readout says 1080 × 1920 px.
        design.element("suite.newdoc.preset").click()
        design.app.menuItems["Story"].firstMatch.click()
        XCTAssertEqual(design.element("suite.newdoc.pixels").value as? String, "1080 × 1920 px")

        // 3. Create: the sheet goes and the new file's one page is 1080 × 1920.
        design.element("suite.newdoc.create").click()
        XCTAssert(waitUntil { !design.element("suite.newdoc").exists }, "Create left the New Document sheet open")
        XCTAssert(statusReads(design.element("suite.status"), "1080 × 1920 pt"), "the status line doesn't read 1080 × 1920 pt")
        design.shot("new-document-story")
    }

    /// The journey itself.
    @MainActor private func walkPageSize() throws {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "the cards fixture showed no page")

        // 1. Click the page's row in Pages: the inspector shows Width 1440 and Height 1024.
        let sidebar = design.element("suite.sidebar")
        let rows = sidebar.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'design.page.row.'"))
        XCTAssert(rows.firstMatch.waitForExistence(timeout: 5), "no page row in Pages (design.page.row.<id>)")
        let pageRow = rows.firstMatch
        pageRow.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
        let inspector = design.element("suite.inspector")
        let width = inspector.descendants(matching: .any)["design.inspector.page-width"].firstMatch
        let height = inspector.descendants(matching: .any)["design.inspector.page-height"].firstMatch
        XCTAssert(width.waitForExistence(timeout: 5), "no Width in the inspector (design.inspector.page-width)")
        XCTAssert(height.exists, "no Height in the inspector (design.inspector.page-height)")
        XCTAssert(waitUntil { self.reads(width, "1440") }, "Width reads \(text(width)), not 1440")
        XCTAssert(reads(height, "1024"), "Height reads \(text(height)), not 1024")
        design.shot("page-size")

        // 2. Click Width, type 800, click the page's row: the status line and the toolbar's Undo say so.
        let status = design.element("suite.status")
        let undo = design.element("design.bar.undo")
        enter("800", into: width, clickingAwayOn: pageRow, in: inspector)
        XCTAssert(waitUntil { self.reads(width, "800") }, "Width reads \(text(width)), not 800")
        XCTAssert(statusReads(status, "800 × 1024 pt"), "the status line doesn't read 800 × 1024 pt")
        XCTAssert(waitUntil { undo.label == "Undo Change Page Size" }, "the toolbar's Undo reads \(undo.label), not Undo Change Page Size")

        // 3. Desktop's part past 800 still shows, dimmed: the canvas is shot and attached.
        design.shot("page-past-the-edge", element: design.element("suite.viewport"))

        // 4. Click Height, type 768, click the page's row: Height reads 768, the status line 800 × 768 pt.
        enter("768", into: height, clickingAwayOn: pageRow, in: inspector)
        XCTAssert(waitUntil { self.reads(height, "768") }, "Height reads \(text(height)), not 768")
        XCTAssert(reads(width, "800"), "changing Height moved Width to \(text(width))")
        XCTAssert(statusReads(status, "800 × 768 pt"), "the status line doesn't read 800 × 768 pt")
        XCTAssert(waitUntil { undo.label == "Undo Change Page Size" }, "after Height the toolbar's Undo reads \(undo.label)")
        design.shot("page-height")

        // 5. Click Undo: Height reads 1024 and Width stays 800, one step; click it again: Width reads 1440.
        undo.click()
        XCTAssert(waitUntil { self.reads(height, "1024") }, "Undo left Height at \(text(height)), not 1024")
        XCTAssert(reads(width, "800"), "undoing Height moved Width to \(text(width))")
        XCTAssert(statusReads(status, "800 × 1024 pt"), "after one Undo the status line doesn't read 800 × 1024 pt")
        undo.click()
        XCTAssert(waitUntil { self.reads(width, "1440") }, "Undo left Width at \(text(width)), not 1440")
        XCTAssert(reads(height, "1024"), "undoing Width moved Height to \(text(height))")
        design.shot("page-size-undone")
    }

    /// Clicks `side`, types `number` over the value the click selected, then clicks `away` to commit:
    /// a mouse user's path, with no Command-A and no Return.
    @MainActor private func enter(
        _ number: String, into side: XCUIElement, clickingAwayOn away: XCUIElement, in inspector: XCUIElement
    ) {
        side.click()
        let field = inspector.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking \(side.identifier) opened no field")
        field.typeText(number)
        away.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click()
        XCTAssert(waitUntil { !field.exists }, "clicking away left the \(side.identifier) field open")
    }

    /// Whether the status line shows `words`, read by label or value, within five seconds.
    @MainActor private func statusReads(_ status: XCUIElement, _ words: String) -> Bool {
        status.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", words, words))
            .firstMatch.waitForExistence(timeout: 5)
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
