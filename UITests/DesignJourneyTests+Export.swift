// DesignJourneyTests+Export.swift: J19, File > Export… on the fakes
// (design-export DE-6, DE-7; docs/blueprints/design/features/design-export.md,
// Journeys). On `-DesignServices fake -DesignFixture cards` at 1024 × 768:
// Desktop's row is clicked, ⇧⌘E opens the export sheet
// (`design.export.sheet`), whose list (`design.export.items`) reads
// "Desktop.png 1440 × 1024, 1x"; the 2x chip (`design.export.scale.2x`)
// makes it "2880 × 2048 px". Export (`design.export.start`) runs the fake
// export, which writes nothing: progress fills, the sheet reads "Exported
// 1 file" and the status line's note (`design.status.note`) repeats it.
// Done (`design.export.dismiss`) closes the sheet; ⇧⌘E again and Cancel
// (`design.export.cancel`) leaves no sheet. J17 (real files) waits on DE-10
// and J18 (no overwrite, Cancel mid-run) on DE-11.
import XCTest

final class DesignExportJourneyTests: XCTestCase {
    static let arguments = ["-DesignServices", "fake", "-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    static let desktopRow = "design.layer.node-1", sheetID = "design.export.sheet", itemsID = "design.export.items"
    static let startID = "design.export.start", doneID = "design.export.dismiss", cancelID = "design.export.cancel"
    static let noteID = "design.status.note"

    /// J17: PNG, SVG and PDF of Desktop land in `-DesignExportTo` at their sizes.
    @MainActor func testExportPNGSVGPDF() throws { throw XCTSkip("waits on DE-10") }

    /// J18: a second export never overwrites the first, and Cancel mid-run stops it.
    @MainActor func testExportNeverOverwritesAndCancels() throws { throw XCTSkip("waits on DE-11") }

    /// J19: ⇧⌘E opens the sheet on Desktop at PNG 1x; 2x doubles the pixels; Export finishes on the fakes.
    @MainActor func testExportSheetOnFakes() throws {
        let design = launch(Self.arguments)
        design.clickDesignLayer(Self.desktopRow)

        // 1. ⇧⌘E: the sheet lists Desktop at 1x.
        design.press(character: "e", [.command, .shift])
        let sheet = design.element(Self.sheetID)
        XCTAssert(sheet.waitForExistence(timeout: 5), "⇧⌘E opened no export sheet (\(Self.sheetID))")
        let items = design.element(Self.itemsID)
        XCTAssert(Self.waitUntil { self.reads(items, "Desktop.png 1440 × 1024, 1x") }, "the list doesn't name Desktop at 1x")
        design.shot("export-sheet")

        // 2. 2x: the row reads twice the pixels.
        design.element("design.export.scale.2x").click()
        XCTAssert(Self.waitUntil { self.reads(items, "2880 × 2048 px") }, "2x left the list without 2880 × 2048 px")
        design.shot("export-sheet-2x")

        // 3. Export: progress fills and the sheet and the status line read the result.
        design.element(Self.startID).click()
        XCTAssert(Self.waitUntil(timeout: 10) { self.reads(sheet, "Exported 1 file") }, "the run never read Exported 1 file")
        let note = design.element(Self.noteID)
        XCTAssert(Self.waitUntil { Self.text(note).contains("Exported 1 file") }, "the status line doesn't repeat the result")
        design.shot("export-finished")

        // 4. Done closes the sheet.
        design.element(Self.doneID).click()
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "Done left the sheet open")

        // 5. ⇧⌘E then Cancel: no sheet remains.
        design.press(character: "e", [.command, .shift])
        XCTAssert(sheet.waitForExistence(timeout: 5), "the second ⇧⌘E opened no sheet")
        design.element(Self.cancelID).click()
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "Cancel left the sheet open")
        XCTAssertFalse(design.app.sheets.firstMatch.exists, "a sheet is still attached after Cancel")
    }

    /// Design launched with `arguments`, its canvas up.
    @MainActor private func launch(_ arguments: [String]) -> Journey {
        let design = Journey("Design", self, arguments: arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "the cards fixture showed no page (suite.canvas)")
        return design
    }

    /// Whether some text inside `element` contains `text`.
    @MainActor private func reads(_ element: XCUIElement, _ text: String) -> Bool {
        let match = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)
        return element.descendants(matching: .any).matching(match).firstMatch.exists
    }

    /// What an element reads: its value, else its label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
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
