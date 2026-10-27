// LibraryJourneyTests+ExportFormats.swift: J7F, export other formats (packet
// docs/blueprints/library/features/export.md, Journey steps; slice EX-c). Its
// own XCTestCase class, like +Export.swift. All live (L): the 24 JPEGs
// `LibraryFiles.writeShoot` writes, imported on launch, with
// `-LibraryExportTo` on a fresh temp folder and a fresh `-LibraryCatalogDir`,
// so Export writes there without a panel. The sheet's controls are EX-6's
// (`library.export.quality`, `library.export.preview`, `library.export.summary`)
// plus the format chips `library.export.format.<JPEG|PNG|TIFF|HEIC>`.
//
// Written before its code (lead.md, contract rule 13, EX-7); EX-8, which
// writes the formats, runs it.
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import XCTest

final class LibraryExportFormatsJourneyTests: XCTestCase {
    /// J7F: PNG hides Quality and writes a PNG, TIFF writes a TIFF, and HEIC
    /// writes a HEIC or is disabled with "This Mac can't write HEIC files.".
    @MainActor func testExportOtherFormats() throws {
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        let out = try LibraryFiles.freshPhotoFolder()
        addTeardownBlock { for url in [folder, catalog, out] { try? FileManager.default.removeItem(at: url) } }
        _ = try LibraryFiles.writeShoot(in: folder)
        let library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path,
            "-LibraryExportTo", out.path, "-LibraryImportOnLaunch",
        ])

        // Step 1: PNG hides Quality, previews IMG_0001.png and writes 89 50 4E 47.
        openSheet(library)
        choose("PNG", library)
        library.shot("export-png")
        XCTAssertFalse(library.element("library.export.quality").exists, "PNG shows the Quality row")
        XCTAssertEqual(Self.text(library.element("library.export.preview")), "IMG_0001.png · 2048 × 1365", "the preview line")
        try export("IMG_0001.png", in: out, library) { [[0x89, 0x50, 0x4E, 0x47]].contains(Array($0.prefix(4))) }

        // Step 2: TIFF writes II*\0 or MM\0*.
        reopen(library)
        choose("TIFF", library)
        try export("IMG_0001.tif", in: out, library) {
            [[0x49, 0x49, 0x2A, 0x00], [0x4D, 0x4D, 0x00, 0x2A]].contains(Array($0.prefix(4)))
        }

        // Step 3: HEIC writes `ftyp` at byte 4, or is disabled with its reason.
        reopen(library)
        let heic = library.element("library.export.format.HEIC")
        XCTAssert(heic.waitForExistence(timeout: 3), "no library.export.format.HEIC")
        if heic.isEnabled {
            choose("HEIC", library)
            try export("IMG_0001.heic", in: out, library) { Array($0.dropFirst(4).prefix(4)) == Array("ftyp".utf8) }
        } else {
            let reason = "This Mac can't write HEIC files."
            let controls = Self.decode(library.element("library.controls"))?.controls ?? []
            XCTAssert(controls.contains { !$0.enabled && $0.reason == reason },
                      "no disabled control in library.controls says \"\(reason)\"")
            heic.click()
            XCTAssertEqual(Self.text(library.element("library.export.preview")), "IMG_0001.jpg · 2048 × 1365",
                           "clicking the disabled HEIC chip changed the format")
        }
        library.app.terminate()
    }

    // MARK: - Steps

    /// By name, IMG_0001 selected, File > Export…: the sheet opens.
    @MainActor private func openSheet(_ library: Journey) {
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(cell("IMG_0024", library).waitForExistence(timeout: 60), "no grid cell for IMG_0024")
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let sort = view.menuItems["Sort By"]
        XCTAssert(sort.waitForExistence(timeout: 3), "the View menu has no Sort By")
        sort.hover()
        sort.menuItems["Name"].click()
        let first = cell("IMG_0001", library)
        XCTAssert(first.waitForExistence(timeout: 10), "no grid cell for IMG_0001")
        first.click()
        openExport(library)
    }

    /// Clicks the format chip `library.export.format.<format>`.
    @MainActor private func choose(_ format: String, _ library: Journey) {
        let chip = library.element("library.export.format.\(format)")
        XCTAssert(chip.waitForExistence(timeout: 3), "no library.export.format.\(format)")
        XCTAssert(chip.isEnabled, "the \(format) chip is disabled")
        chip.click()
    }

    /// Export, then `name` exists in `out` and its bytes pass `magic`.
    @MainActor private func export(_ name: String, in out: URL, _ library: Journey, magic: (Data) -> Bool) throws {
        sheetButton("Export", library).click()
        let summary = library.element("library.export.summary")
        XCTAssert(summary.waitForExistence(timeout: 60), "no summary (library.export.summary)")
        let bytes = try Data(contentsOf: out.appending(path: name))
        XCTAssert(magic(bytes), "\(name) starts \(Array(bytes.prefix(8))), the wrong container")
        XCTAssertNotNil(CGImageSourceCreateWithData(bytes as CFData, nil), "\(name) isn't an image")
    }

    // MARK: - Helpers

    /// Closes the sheet (Done or Close) and opens File > Export… again.
    @MainActor private func reopen(_ library: Journey) {
        let sheet = library.app.sheets.firstMatch
        let button = ["Done", "Close"].lazy.map { self.sheetButton($0, library) }.first { $0.exists }
        XCTAssertNotNil(button, "the export sheet has no Done or Close")
        button?.click()
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "the export sheet didn't close")
        openExport(library)
    }

    /// File > Export…, which must be enabled, then the sheet.
    @MainActor private func openExport(_ library: Journey) {
        let file = library.app.menuBars.firstMatch.menuBarItems["File"]
        XCTAssert(file.waitForExistence(timeout: 5), "no File menu")
        file.click()
        let item = file.menuItems["Export…"]
        XCTAssert(item.waitForExistence(timeout: 3), "the File menu has no Export…")
        XCTAssert(item.isEnabled, "File > Export… is disabled with a photo selected")
        item.click()
        XCTAssert(library.app.sheets.firstMatch.waitForExistence(timeout: 5), "File > Export… opened no sheet")
    }

    /// The sheet's button titled `title`.
    @MainActor private func sheetButton(_ title: String, _ library: Journey) -> XCUIElement {
        library.app.sheets.firstMatch.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// The grid cell `library.grid.cell.<id>` whose photo id names `name`.
    @MainActor private func cell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }

    /// What an element reads: its value where macOS puts a field's text, else its label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }

    /// `library.controls`' JSON, the window's control inventory.
    @MainActor private static func decode(_ probe: XCUIElement) -> ControlDocument? {
        guard probe.waitForExistence(timeout: 5) else { return nil }
        return try? JSONDecoder().decode(ControlDocument.self, from: Data(probe.label.utf8))
    }
}
