// LibraryJourneyTests+ExportSidecars.swift: J7S, export with XMP sidecars
// (packet docs/blueprints/library/features/export.md, Journey steps; slice
// EX-f). Its own XCTestCase class, like +Export.swift. All live (L): the 24
// JPEGs `LibraryFiles.writeShoot` writes, imported on launch, with
// `-LibraryExportTo` on a fresh temp folder and a fresh `-LibraryCatalogDir`,
// so Export writes there without a panel. The sheet's controls are EX-6's
// (`library.export.preview`, `library.export.summary`); its buttons and the
// Write Sidecar checkbox are found by title.
//
// Written before its code (lead.md, contract rule 13, EX-15); EX-16, which
// writes the XMP, made it live.
import Foundation
import XCTest

final class LibraryExportSidecarsJourneyTests: XCTestCase {
    /// J7S: with Write Sidecar on, each exported JPEG gets an `.xmp` beside it
    /// holding its rating, and a second export replaces neither file.
    @MainActor func testExportWithSidecars() throws {
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        let out = try LibraryFiles.freshPhotoFolder()
        addTeardownBlock { for url in [folder, catalog, out] { try? FileManager.default.removeItem(at: url) } }
        try LibraryFiles.writeShoot(in: folder)
        let library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path,
            "-LibraryExportTo", out.path, "-LibraryImportOnLaunch",
        ])

        // Step 1: IMG_0001 in the loupe, 3 then P; Export… with Write Sidecar on.
        rateAndPickInLoupe(library)
        openSheetWithSidecar(library)
        library.shot("export-sidecar")
        XCTAssertEqual(Self.text(library.element("library.export.preview")), "IMG_0001.jpg + .xmp · 2048 × 1365",
                       "the preview line")

        // Step 2: Export writes IMG_0001.jpg and IMG_0001.xmp, the XMP rated 3.
        try exportAndExpect(jpeg: "IMG_0001.jpg", xmp: "IMG_0001.xmp", in: out, library)
        let first = try ["IMG_0001.jpg", "IMG_0001.xmp"].map { try Data(contentsOf: out.appending(path: $0)) }

        // Step 3: again: IMG_0001 2.jpg and IMG_0001 2.xmp; the first pair is untouched.
        closeSheet(library)
        openSheetWithSidecar(library)
        try exportAndExpect(jpeg: "IMG_0001 2.jpg", xmp: "IMG_0001 2.xmp", in: out, library)
        let again = try ["IMG_0001.jpg", "IMG_0001.xmp"].map { try Data(contentsOf: out.appending(path: $0)) }
        XCTAssertEqual(again, first, "the second export replaced IMG_0001.jpg or IMG_0001.xmp")
        closeSheet(library)
        library.app.terminate()
    }

    // MARK: - Steps

    /// Waits for the import, sorts by name, opens IMG_0001 in the loupe and presses 3, then P.
    @MainActor private func rateAndPickInLoupe(_ library: Journey) {
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(gridCell("IMG_0024", library).waitForExistence(timeout: 60), "no grid cell for IMG_0024")
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let sortBy = view.menuItems["Sort By"]
        XCTAssert(sortBy.waitForExistence(timeout: 3), "the View menu has no Sort By")
        sortBy.hover()
        let name = sortBy.menuItems["Name"]
        XCTAssert(name.waitForExistence(timeout: 3), "View > Sort By has no Name")
        name.click()
        let first = gridCell("IMG_0001", library)
        XCTAssert(first.waitForExistence(timeout: 10), "no grid cell for IMG_0001")
        first.doubleClick()
        XCTAssert(library.element("library.loupe").waitForExistence(timeout: 10), "double-click didn't open the loupe")
        library.element("library.loupe.photo").click()
        library.press(character: "3")
        library.press(character: "p")
    }

    /// File > Export… (enabled in the loupe), then the Write Sidecar checkbox on.
    @MainActor private func openSheetWithSidecar(_ library: Journey) {
        let file = library.app.menuBars.firstMatch.menuBarItems["File"]
        XCTAssert(file.waitForExistence(timeout: 5), "no File menu")
        file.click()
        let export = file.menuItems["Export…"]
        XCTAssert(export.waitForExistence(timeout: 3), "the File menu has no Export…")
        XCTAssert(export.isEnabled, "File > Export… is disabled with IMG_0001 in the loupe")
        export.click()
        let sheet = library.app.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: 5), "File > Export… opened no sheet")
        let sidecar = sheet.checkBoxes.matching(NSPredicate(format: "label == %@", "Write Sidecar")).firstMatch
        XCTAssert(sidecar.waitForExistence(timeout: 3), "the sheet has no Write Sidecar checkbox")
        XCTAssert(sidecar.isEnabled, "Write Sidecar is disabled")
        if (sidecar.value as? Int ?? 0) == 0 { sidecar.click() }
        XCTAssertEqual(sidecar.value as? Int, 1, "Write Sidecar didn't turn on")
    }

    /// Export, then the summary "Exported 1 photo." and `jpeg` and `xmp` in
    /// `out`, the XMP holding `xmp:Rating="3"`.
    @MainActor private func exportAndExpect(jpeg: String, xmp: String, in out: URL, _ library: Journey) throws {
        sheetButton("Export", library).click()
        let summary = library.element("library.export.summary")
        XCTAssert(summary.waitForExistence(timeout: 60), "no summary (library.export.summary)")
        XCTAssertEqual(Self.text(summary), "Exported 1 photo.", "the summary")
        let bytes = try Data(contentsOf: out.appending(path: jpeg))
        XCTAssertEqual([UInt8](bytes.prefix(2)), [0xFF, 0xD8], "\(jpeg) doesn't start FF D8")
        let packet = try String(contentsOf: out.appending(path: xmp), encoding: .utf8)
        XCTAssert(packet.contains("xmp:Rating=\"3\""), "\(xmp) has no xmp:Rating=\"3\": \(packet)")
    }

    // MARK: - Helpers

    /// The sheet's Done or Close button, then the sheet is gone.
    @MainActor private func closeSheet(_ library: Journey) {
        let sheet = library.app.sheets.firstMatch
        guard sheet.exists else { return }
        let button = ["Done", "Close"].lazy.map { self.sheetButton($0, library) }.first { $0.exists }
        XCTAssertNotNil(button, "the export sheet has no Done or Close")
        button?.click()
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "the export sheet didn't close")
    }

    /// The sheet's button titled `title`.
    @MainActor private func sheetButton(_ title: String, _ library: Journey) -> XCUIElement {
        library.app.sheets.firstMatch.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// The grid cell `library.grid.cell.<id>` whose photo id names `name`.
    @MainActor private func gridCell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }

    /// What an element reads: its value where macOS puts a field's text, else its label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }
}
