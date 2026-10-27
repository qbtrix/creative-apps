// LibraryJourneyTests+Export.swift: J7, export JPEGs at a size (packet
// docs/blueprints/library/features/export.md, Journey steps; slice EX-b;
// blueprint J7 steps 1-4 and 7). Its own XCTestCase class, like +Develop.swift.
// The fake pass (F) runs steps 1 and 5 on the `shoot` fixture; the live pass
// (L) runs steps 1 to 5 on the 24 JPEGs `LibraryFiles.writeShoot` writes,
// imported on launch, its shots ending `-live`. Every launch passes
// `-LibraryExportTo` on a fresh temp folder and a fresh `-LibraryCatalogDir`,
// so Export writes there without a panel. The sheet's controls are EX-6's:
// `library.export.longEdge`, `library.export.quality`, `library.export.preview`,
// the progress row `library.export.progress` and the summary
// `library.export.summary`; its buttons are found by title.
//
// Written before its code (lead.md, contract rule 13, EX-4); EX-6, which
// builds the sheet, enabled it.
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import XCTest

final class LibraryExportJourneyTests: XCTestCase {
    /// J7: File > Export… writes the selected photos as JPEGs at a long edge
    /// into a folder, never over an earlier file, and is off with no selection.
    @MainActor func testExportJPEGsAtASize() throws {
        // (F) steps 1 and 5 on the fakes.
        let fakeOut = try LibraryFiles.freshPhotoFolder()
        let fakeCatalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [fakeOut, fakeCatalog] { try? FileManager.default.removeItem(at: url) } }
        var library = Journey("Library", self, arguments: [
            "-LibraryFixture", "shoot", "-LibraryExportTo", fakeOut.path, "-LibraryCatalogDir", fakeCatalog.path,
        ])
        openSheet(library, suffix: "")
        closeAndDeselect(library)
        library.app.terminate()

        // (L) steps 1 to 5 on real files.
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        let out = try LibraryFiles.freshPhotoFolder()
        addTeardownBlock { for url in [folder, catalog, out] { try? FileManager.default.removeItem(at: url) } }
        try LibraryFiles.writeShoot(in: folder)
        library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path,
            "-LibraryExportTo", out.path, "-LibraryImportOnLaunch",
        ])
        openSheet(library, suffix: "-live")
        exportAt1024(library, shot: "exporting")
        try expectExported(["IMG_0001.jpg", "IMG_0002.jpg"], in: out, library)
        let first = try ["IMG_0001.jpg", "IMG_0002.jpg"].map { try Data(contentsOf: out.appending(path: $0)) }

        // Step 4 (L): the same two again add "IMG_0001 2.jpg" and leave the first files alone.
        closeSheet(library)
        openExport(library)
        exportAt1024(library, shot: nil)
        try expectExported(["IMG_0001 2.jpg", "IMG_0002 2.jpg"], in: out, library)
        let again = try ["IMG_0001.jpg", "IMG_0002.jpg"].map { try Data(contentsOf: out.appending(path: $0)) }
        XCTAssertEqual(again, first, "the second export changed IMG_0001.jpg or IMG_0002.jpg")
        closeAndDeselect(library)
        library.app.terminate()
    }

    // MARK: - Steps

    /// Step 1: by name, IMG_0001 and IMG_0002 selected, File > Export…: the
    /// sheet reads "Export 2 Photos", 2048, 85 and the first file's preview.
    @MainActor private func openSheet(_ library: Journey, suffix: String) {
        sortByName(library)
        let first = cell("IMG_0001", library)
        XCTAssert(first.waitForExistence(timeout: 10), "no grid cell for IMG_0001")
        first.click()
        selectSecond(library)
        openExport(library)
        let sheet = library.app.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: 5), "File > Export… opened no sheet")
        library.shot("export-sheet\(suffix)")
        let title = sheet.staticTexts.matching(NSPredicate(format: "label == %@", "Export 2 Photos")).firstMatch
        XCTAssert(title.exists, "the sheet's title isn't \"Export 2 Photos\"")
        XCTAssertEqual(Self.text(library.element("library.export.longEdge")), "2048", "the long edge")
        XCTAssertEqual(Self.text(library.element("library.export.quality")), "85", "the quality")
        XCTAssertEqual(Self.text(library.element("library.export.preview")), "IMG_0001.jpg · 2048 × 1365", "the preview line")
        if let screen = NSScreen.main?.frame {
            XCTAssert(sheet.frame.width <= screen.width && sheet.frame.height <= screen.height,
                      "the sheet (\(sheet.frame)) is bigger than the display (\(screen))")
            XCTAssert(sheet.frame.minX >= 0 && sheet.frame.minY >= 0, "the sheet starts off the display: \(sheet.frame)")
        }
    }

    /// Step 2 (L): long edge 1024 and quality 80, then Export: the progress
    /// row "Exporting 1 of 2" with Cancel, or the summary if both were done.
    @MainActor private func exportAt1024(_ library: Journey, shot: String?) {
        set("library.export.longEdge", to: "1024", library)
        set("library.export.quality", to: "80", library)
        sheetButton("Export", library).click()
        let progress = library.element("library.export.progress")
        let summary = library.element("library.export.summary")
        XCTAssert(wait(5) { progress.exists || summary.exists }, "Export showed neither progress nor a summary")
        if let shot { library.shot(shot) }
        if progress.exists, !summary.exists {
            XCTAssert(Self.text(progress).hasPrefix("Exporting "), "the progress row reads \(Self.text(progress))")
            XCTAssert(sheetButton("Cancel", library).exists, "the progress row has no Cancel")
        }
    }

    /// Step 3 (L): "Exported 2 photos." with Show in Finder; `names` are JPEGs with a long edge of 1024.
    @MainActor private func expectExported(_ names: [String], in out: URL, _ library: Journey) throws {
        let summary = library.element("library.export.summary")
        XCTAssert(summary.waitForExistence(timeout: 60), "no summary (library.export.summary)")
        XCTAssert(wait(5) { Self.text(summary) == "Exported 2 photos." }, "the summary reads \(Self.text(summary))")
        XCTAssert(sheetButton("Show in Finder", library).exists, "the summary has no Show in Finder")
        if names.first == "IMG_0001.jpg" { library.shot("exported") }
        for name in names {
            let url = out.appending(path: name)
            let bytes = try Data(contentsOf: url)
            XCTAssertEqual([UInt8](bytes.prefix(2)), [0xFF, 0xD8], "\(name) doesn't start FF D8")
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil), "\(name) isn't an image")
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
            let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
            XCTAssertEqual(max(width, height), 1024, "\(name) is \(width) × \(height), not 1024 on its long edge")
        }
    }

    /// Step 5 (F, L): close the sheet, Escape to the grid, Deselect: File >
    /// Export… is off and says "Select a photo to export it.".
    @MainActor private func closeAndDeselect(_ library: Journey) {
        closeSheet(library)
        library.press(.escape)
        library.press(character: "a", [.command, .shift])
        let file = library.app.menuBars.firstMatch.menuBarItems["File"]
        file.click()
        let export = file.menuItems["Export…"]
        XCTAssert(export.waitForExistence(timeout: 3), "the File menu has no Export…")
        XCTAssertFalse(export.isEnabled, "File > Export… is enabled with nothing selected")
        library.press(.escape)
        let reason = "Select a photo to export it."
        let controls = Self.decode(library.element("library.controls"))?.controls ?? []
        XCTAssert(controls.contains { !$0.enabled && $0.reason == reason },
                  "no disabled control in library.controls says \"\(reason)\"")
    }

    // MARK: - Helpers

    /// File > Export…, which must be enabled.
    @MainActor private func openExport(_ library: Journey) {
        let file = library.app.menuBars.firstMatch.menuBarItems["File"]
        XCTAssert(file.waitForExistence(timeout: 5), "no File menu")
        file.click()
        let item = file.menuItems["Export…"]
        XCTAssert(item.waitForExistence(timeout: 3), "the File menu has no Export…")
        XCTAssert(item.isEnabled, "File > Export… is disabled with two photos selected")
        item.click()
    }

    /// The sheet's Done, Close or (before an export) Cancel button, then the sheet is gone.
    @MainActor private func closeSheet(_ library: Journey) {
        let sheet = library.app.sheets.firstMatch
        guard sheet.exists else { return }
        let button = ["Done", "Close", "Cancel"].lazy.map { self.sheetButton($0, library) }.first { $0.exists }
        XCTAssertNotNil(button, "the export sheet has no Done, Close or Cancel")
        button?.click()
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "the export sheet didn't close")
    }

    /// Command-clicks IMG_0002, so IMG_0001 and IMG_0002 are selected.
    @MainActor private func selectSecond(_ library: Journey) {
        XCUIElement.perform(withKeyModifiers: .command) { cell("IMG_0002", library).click() }
    }

    /// Replaces the field `identifier`'s text with `text` and commits it.
    @MainActor private func set(_ identifier: String, to text: String, _ library: Journey) {
        let field = library.element(identifier)
        XCTAssert(field.waitForExistence(timeout: 3), "no \(identifier)")
        field.click()
        library.press(character: "a", .command)
        library.app.typeText(text)
        library.press(.tab)
        XCTAssert(wait(3) { Self.text(field) == text }, "\(identifier) reads \(Self.text(field)), not \(text)")
    }

    /// The sheet's button titled `title`.
    @MainActor private func sheetButton(_ title: String, _ library: Journey) -> XCUIElement {
        library.app.sheets.firstMatch.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// Polls `condition` every tenth of a second for up to `seconds`.
    @MainActor private func wait(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: seconds)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        return condition()
    }

    /// The grid cell `library.grid.cell.<id>` whose photo id names `name`.
    @MainActor private func cell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }

    /// Waits for the window and IMG_0024's cell, then View > Sort By > Name.
    @MainActor private func sortByName(_ library: Journey) {
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(cell("IMG_0024", library).waitForExistence(timeout: 60), "no grid cell for IMG_0024")
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let sort = view.menuItems["Sort By"]
        XCTAssert(sort.waitForExistence(timeout: 3), "the View menu has no Sort By")
        sort.hover()
        let byName = sort.menuItems["Name"]
        XCTAssert(byName.waitForExistence(timeout: 3), "View > Sort By has no Name")
        byName.click()
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
