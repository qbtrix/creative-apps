// LibraryJourneyTests+ExportBatch.swift: J7B, a batch export that fails,
// cancels and shows its progress (packet docs/blueprints/library/features/
// export.md; slice EX-e). Steps 1-2 are live (L) on `LibraryFiles.writeShoot`'s
// JPEGs; step 3 is fake (F) with `-LibraryFakeMode slow`. EX-6's sheet ids;
// buttons and size chips by title. Written by EX-12 before its code and
// enabled by EX-13, which makes Cancel and Try Again work.
import Foundation
import XCTest

final class LibraryExportBatchJourneyTests: XCTestCase {
    /// J7B: a read-only folder lists each failure with Try Again; Cancel stops
    /// a 24-photo export part way; the progress row shows within 2 s.
    @MainActor func testExportFailsAndCancels() throws {
        let folder = try LibraryFiles.freshPhotoFolder()
        try LibraryFiles.writeShoot(in: folder)
        let readOnly = try LibraryFiles.readOnlyFolder()
        let out = try LibraryFiles.freshPhotoFolder()
        let catalogs = try (0..<3).map { _ in try LibraryFiles.freshCatalogDir() }
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnly.path)
            for url in [folder, readOnly, out] + catalogs { try? FileManager.default.removeItem(at: url) }
        }

        // Step 1 (L): IMG_0001 and IMG_0002 into a read-only folder: both fail, with Try Again.
        var library = live(folder, catalog: catalogs[0], exportTo: readOnly)
        sortByName(library)
        select(["IMG_0001", "IMG_0002"], library)
        openExport(library)
        sheetButton("Export", library).click()
        let summary = library.element("library.export.summary")
        XCTAssert(summary.waitForExistence(timeout: 60), "no summary (library.export.summary)")
        library.shot("export-failed")
        XCTAssertEqual(Self.text(summary), "2 photos couldn't be exported.", "the summary")
        let failures = Self.text(library.element("library.export.failures"))
        for name in ["IMG_0001.jpg", "IMG_0002.jpg"] {
            XCTAssert(failures.contains("\(name): "), "library.export.failures has no \"\(name): reason\": \(failures)")
        }
        XCTAssert(sheetButton("Try Again", library).exists, "the failed summary has no Try Again")
        library.app.terminate()

        // Step 2 (L): all 24 at Original Size into a writable folder; Cancel at "Exporting 2 of 24".
        library = live(folder, catalog: catalogs[1], exportTo: out)
        sortByName(library)
        library.press(character: "a", .command)
        openExport(library)
        let original = sheetControl("Original Size", library)
        XCTAssert(original.waitForExistence(timeout: 3), "the sheet has no Original Size")
        original.click()
        sheetButton("Export", library).click()
        let progress = library.element("library.export.progress")
        let summaryAll = library.element("library.export.summary")
        XCTAssert(wait(60) { Self.text(progress) == "Exporting 2 of 24" || summaryAll.exists },
                  "the progress row never read \"Exporting 2 of 24\"")
        sheetButton("Cancel", library).click()
        XCTAssert(summaryAll.waitForExistence(timeout: 60), "Cancel showed no summary")
        library.shot("export-cancelled")
        let cancelled = ["Exported 1 of 24. Export was cancelled.", "Exported 2 of 24. Export was cancelled."]
        XCTAssert(cancelled.contains(Self.text(summaryAll)), "the summary reads \(Self.text(summaryAll))")
        let written = (try? FileManager.default.contentsOfDirectory(atPath: out.path)) ?? []
        XCTAssert(written.count < 24, "Cancel still wrote all 24: \(written.count) files")
        library.app.terminate()

        // Step 3 (F): three photos on the slow fakes show the progress row within 2 s.
        library = Journey("Library", self, arguments: [
            "-LibraryFixture", "shoot", "-LibraryFakeMode", "slow",
            "-LibraryCatalogDir", catalogs[2].path, "-LibraryExportTo", out.path,
        ])
        sortByName(library)
        select(["IMG_0001", "IMG_0002", "IMG_0003"], library)
        openExport(library)
        sheetButton("Export", library).click()
        XCTAssert(library.element("library.export.progress").waitForExistence(timeout: 2),
                  "no progress row (library.export.progress) within 2 s")
        library.app.terminate()
    }

    // MARK: - Steps (P8 in +PerfExport.swift uses them too)

    /// Library on the JPEGs in `folder`, imported on launch, exporting to `exportTo`.
    @MainActor func live(_ folder: URL, catalog: URL, exportTo: URL) -> Journey {
        Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path,
            "-LibraryExportTo", exportTo.path, "-LibraryImportOnLaunch",
        ])
    }

    /// Clicks the first of `names`, then command-clicks the rest.
    @MainActor func select(_ names: [String], _ library: Journey) {
        guard let first = names.first else { return }
        let firstCell = cell(first, library)
        XCTAssert(firstCell.waitForExistence(timeout: 10), "no grid cell for \(first)")
        firstCell.click()
        for name in names.dropFirst() {
            XCUIElement.perform(withKeyModifiers: .command) { self.cell(name, library).click() }
        }
    }

    /// File > Export…, which must be enabled, then the sheet.
    @MainActor func openExport(_ library: Journey) {
        let file = library.app.menuBars.firstMatch.menuBarItems["File"]
        XCTAssert(file.waitForExistence(timeout: 5), "no File menu")
        file.click()
        let item = file.menuItems["Export…"]
        XCTAssert(item.waitForExistence(timeout: 3), "the File menu has no Export…")
        XCTAssert(item.isEnabled, "File > Export… is disabled with photos selected")
        item.click()
        XCTAssert(library.app.sheets.firstMatch.waitForExistence(timeout: 5), "File > Export… opened no sheet")
    }

    /// Waits for the window and IMG_0024's cell, then View > Sort By > Name.
    @MainActor func sortByName(_ library: Journey) {
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

    @MainActor func sheetButton(_ title: String, _ library: Journey) -> XCUIElement {
        library.app.sheets.firstMatch.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// Any control in the sheet titled `title` (a size chip is a button or a radio button).
    @MainActor func sheetControl(_ title: String, _ library: Journey) -> XCUIElement {
        library.app.sheets.firstMatch.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// Polls `condition` for up to `seconds`.
    @MainActor func wait(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: seconds)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < deadline
        return condition()
    }

    /// The grid cell `library.grid.cell.<id>` whose photo id names `name`.
    @MainActor func cell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }

    /// What an element reads: its value where macOS puts a field's text, else its label.
    @MainActor static func text(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }
}
