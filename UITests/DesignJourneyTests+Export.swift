// DesignJourneyTests+Export.swift: J19, File > Export… on the fakes
// (design-export DE-6, DE-7; docs/blueprints/design/features/design-export.md,
// Journeys). On `-DesignServices fake -DesignFixture cards` at 1024 × 768:
// Desktop's row is clicked, ⇧⌘E opens the export sheet
// (`design.export.sheet`), whose list (`design.export.items`) reads
// "Desktop.png 1440 × 1024 pt, 1x"; the 2x chip (`design.export.scale.2x`)
// makes it "2880 × 2048 px". Export (`design.export.start`) runs the fake
// export, which writes nothing: progress fills, the sheet reads "Exported
// 1 file" and the status line's note (`design.status.note`) repeats it.
// Done (`design.export.dismiss`) closes the sheet; ⇧⌘E again and Cancel
// (`design.export.cancel`) leaves no sheet. J17 and J18 (DE-10, DE-11) run on
// the live services with `-DesignExportTo <tmp folder>`, which stands in for
// the folder panel: J17 writes Desktop as PNG 2x, SVG and PDF and reads each
// file back; J18 exports PNG 1x twice ("Desktop 2.png" beside an unchanged
// "Desktop.png"), Escape and Cancel write nothing, and a read-only folder
// ends the run on the failed line with the system's reason (its curly apostrophe,
// "You don’t have permission", as Foundation words it).
import CoreGraphics
import ImageIO
import XCTest

final class DesignExportJourneyTests: XCTestCase {
    static let arguments = ["-DesignServices", "fake", "-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    static let desktopRow = "design.layer.node-1", sheetID = "design.export.sheet", itemsID = "design.export.items"
    static let startID = "design.export.start", doneID = "design.export.dismiss", cancelID = "design.export.cancel"
    static let noteID = "design.status.note"

    /// J17: PNG, SVG and PDF of Desktop land in `-DesignExportTo` at their sizes.
    @MainActor func testExportPNGSVGPDF() throws {
        let folder = try Self.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let design = launch(Self.live(folder))
        design.clickDesignLayer(Self.desktopRow)

        // 1. File > Export…: the sheet lists Desktop at 1x; 2x doubles it.
        let file = design.app.menuBars.firstMatch.menuBarItems["File"]
        file.click()
        let export = file.menuItems["Export…"]
        XCTAssert(export.waitForExistence(timeout: 3), "the File menu shows no Export…")
        export.click()
        let sheet = design.element(Self.sheetID), items = design.element(Self.itemsID)
        XCTAssert(sheet.waitForExistence(timeout: 5), "File > Export… opened no sheet")
        XCTAssert(Self.waitUntil { self.reads(items, "Desktop.png 1440 × 1024 pt, 1x") }, "the list doesn't name Desktop at 1x")
        design.element("design.export.scale.2x").click()
        XCTAssert(Self.waitUntil { self.reads(items, "2880 × 2048 px") }, "2x left the list without 2880 × 2048 px")

        // 2. Export: the finished line and the status line name the folder; Desktop.png is 2880 × 2048.
        let done = "Exported 1 file to \(folder.lastPathComponent)"
        design.element(Self.startID).click()
        XCTAssert(Self.waitUntil(timeout: 10) { self.reads(sheet, done) }, "the run never read \(done)")
        XCTAssert(Self.waitUntil { Self.text(design.element(Self.noteID)).contains(done) }, "the status line doesn't say \(done)")
        design.shot("export-live-png")
        let png = try Data(contentsOf: folder.appendingPathComponent("Desktop.png"))
        let image = CGImageSourceCreateWithData(png as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
        XCTAssertEqual(image?.width, 2880, "Desktop.png isn't 2880 px wide")
        XCTAssertEqual(image?.height, 2048, "Desktop.png isn't 2048 px high")
        design.element(Self.doneID).click()

        // 3. ⇧⌘E, SVG, Export: Desktop.svg's first element is <svg with the frame's viewBox.
        exportAgain(design, format: "svg", expecting: "Exported 1 file to")
        let svg = try String(contentsOf: folder.appendingPathComponent("Desktop.svg"), encoding: .utf8)
        XCTAssert(svg.hasPrefix("<svg") && svg.contains("viewBox=\"0 0 1440 1024\""), "Desktop.svg isn't the frame's SVG")

        // 4. ⇧⌘E, PDF, Export: Desktop.pdf opens with one page.
        exportAgain(design, format: "pdf", expecting: "Exported 1 file to")
        let pdf = CGPDFDocument(folder.appendingPathComponent("Desktop.pdf") as CFURL)
        XCTAssertEqual(pdf?.numberOfPages, 1, "Desktop.pdf doesn't open with one page")
        design.shot("export-live-pdf")
    }

    /// J18: a second export never overwrites the first, Escape and Cancel write nothing, and a
    /// read-only folder fails the run with the file's name and the system's reason.
    @MainActor func testExportNeverOverwritesAndCancels() throws {
        let folder = try Self.makeFolder()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
            try? FileManager.default.removeItem(at: folder)
        }
        let design = launch(Self.live(folder))
        design.clickDesignLayer(Self.desktopRow)

        // 1. PNG 1x twice: Desktop.png, then Desktop 2.png beside it, the first unchanged.
        exportAgain(design, format: "png", expecting: "Exported 1 file to")
        let first = folder.appendingPathComponent("Desktop.png")
        let bytes = try Data(contentsOf: first)
        exportAgain(design, format: "png", expecting: "Exported 1 file to")
        XCTAssertEqual(try Self.listing(folder), ["Desktop 2.png", "Desktop.png"], "the second export didn't pick a new name")
        XCTAssertEqual(try Data(contentsOf: first), bytes, "the second export changed Desktop.png")
        design.shot("export-no-overwrite")

        // 2. Escape on an open sheet, then Cancel: no third file.
        let sheet = design.element(Self.sheetID)
        design.press(character: "e", [.command, .shift])
        XCTAssert(sheet.waitForExistence(timeout: 5), "⇧⌘E opened no sheet")
        design.press(.escape)
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "Escape left the sheet open")
        design.press(character: "e", [.command, .shift])
        XCTAssert(sheet.waitForExistence(timeout: 5), "⇧⌘E opened no sheet after Escape")
        design.element(Self.cancelID).click()
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "Cancel left the sheet open")
        XCTAssertEqual(try Self.listing(folder).count, 2, "Escape or Cancel wrote a file")

        // 3. Nothing selected: the sheet opens on Frame and lists every top-level frame.
        design.element("suite.canvas").coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.98)).click()
        design.press(character: "e", [.command, .shift])
        XCTAssert(sheet.waitForExistence(timeout: 5), "⇧⌘E opened no sheet with nothing selected")
        XCTAssert(design.element("design.export.scope.frame").isSelected, "the sheet didn't open on Frame")
        XCTAssert(Self.waitUntil { self.reads(design.element(Self.itemsID), "Desktop") }, "the list doesn't hold Desktop")

        // 4. A read-only folder: the failed line names Desktop 3.png and the system's reason.
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
        design.element(Self.startID).click()
        XCTAssert(
            Self.waitUntil(timeout: 10) { self.reads(sheet, "Desktop 3.png couldn't be written. You don’t have permission") },
            "the read-only folder didn't fail on Desktop 3.png with the system's reason")
        design.shot("export-failed")
        XCTAssert(design.element("suite.canvas").exists, "the window lost its document")
        design.element(Self.cancelID).click()
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "Cancel left the failed sheet open")
        XCTAssertEqual(try Self.listing(folder).count, 2, "the failed run left a file")
    }

    /// J19: ⇧⌘E opens the sheet on Desktop at PNG 1x; 2x doubles the pixels; Export finishes on the fakes.
    @MainActor func testExportSheetOnFakes() throws {
        let design = launch(Self.arguments)
        design.clickDesignLayer(Self.desktopRow)

        // 1. ⇧⌘E: the sheet lists Desktop at 1x.
        design.press(character: "e", [.command, .shift])
        let sheet = design.element(Self.sheetID)
        XCTAssert(sheet.waitForExistence(timeout: 5), "⇧⌘E opened no export sheet (\(Self.sheetID))")
        let items = design.element(Self.itemsID)
        XCTAssert(Self.waitUntil { self.reads(items, "Desktop.png 1440 × 1024 pt, 1x") }, "the list doesn't name Desktop at 1x")
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

    /// ⇧⌘E, the `format` chip, Export: the finished line reads `expecting`, then Done.
    @MainActor private func exportAgain(_ design: Journey, format: String, expecting: String) {
        let sheet = design.element(Self.sheetID)
        design.press(character: "e", [.command, .shift])
        XCTAssert(sheet.waitForExistence(timeout: 5), "⇧⌘E opened no sheet for \(format)")
        design.element("design.export.format.\(format)").click()
        design.element(Self.startID).click()
        XCTAssert(Self.waitUntil(timeout: 10) { self.reads(sheet, expecting) }, "the \(format) run never read \(expecting)")
        design.element(Self.doneID).click()
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "Done left the \(format) sheet open")
    }

    /// The live services on `cards`, exporting into `folder`.
    private static func live(_ folder: URL) -> [String] {
        ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768", "-DesignExportTo", folder.path]
    }

    /// A new empty folder under the temporary directory.
    private static func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("design-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// The folder's file names, sorted.
    private static func listing(_ folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
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
