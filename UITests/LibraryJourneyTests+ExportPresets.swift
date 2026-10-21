// LibraryJourneyTests+ExportPresets.swift: J7N, export presets and name
// templates (packet docs/blueprints/library/features/export.md, Journey
// steps; slice EX-d). Its own XCTestCase class, like +Export.swift. Live only
// (L): the 24 JPEGs `LibraryFiles.writeShoot` writes, imported on launch,
// with `-LibraryExportTo` on a fresh temp folder and a fresh
// `-LibraryCatalogDir`, so the preset store (`export-presets.json` beside the
// catalog file) starts clean. The sheet's name field is `library.export.name`
// and its preset menu `library.export.preset` (EX-11); the rest are EX-6's.
//
// EX-11 stores the presets and the last options (Cancel keeps the edited
// ones), so step 4's relaunch finds them.
import AppKit
import Foundation
import XCTest

final class LibraryExportPresetsJourneyTests: XCTestCase {
    /// J7N: a preset sets every option, a name template names the files with
    /// a live preview, and the last settings and saved presets survive a relaunch.
    @MainActor func testExportPresetsAndNames() throws {
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        let out = try LibraryFiles.freshPhotoFolder()
        addTeardownBlock { for url in [folder, catalog, out] { try? FileManager.default.removeItem(at: url) } }
        try LibraryFiles.writeShoot(in: folder)
        let arguments = [
            "-LibraryImportFolder", folder.path, "-LibraryImportOnLaunch",
            "-LibraryCatalogDir", catalog.path, "-LibraryExportTo", out.path,
        ]
        var library = Journey("Library", self, arguments: arguments)

        // Step 1: IMG_0001 to IMG_0003, Export…, preset For Sharing: 2048, 85, JPEG.
        waitForGrid(library)
        sortByName(library)
        cell("IMG_0001", library).click()
        XCUIElement.perform(withKeyModifiers: .shift) { cell("IMG_0003", library).click() }
        openExport(library)
        choosePreset("For Sharing", library)
        XCTAssertEqual(Self.text(library.element("library.export.longEdge")), "2048", "the long edge")
        XCTAssertEqual(Self.text(library.element("library.export.quality")), "85", "the quality")

        // Step 2: {date}-{seq} names the files, previewed first.
        type("{date}-{seq}", into: "library.export.name", library)
        library.shot("export-names")
        XCTAssertEqual(Self.text(library.element("library.export.preview")), "2026-06-01-1.jpg · 2048 × 1365",
                       "the preview line")
        sheetButton("Export", library).click()
        let summary = library.element("library.export.summary")
        XCTAssert(summary.waitForExistence(timeout: 60), "no summary (library.export.summary)")
        for name in ["2026-06-01-1.jpg", "2026-06-01-2.jpg", "2026-06-01-3.jpg"] {
            XCTAssert(FileManager.default.fileExists(atPath: out.appending(path: name).path), "no \(name) in the folder")
        }

        // Step 3: 1200 and 70, Save as Preset… "Web 1200", close.
        sheetButton("Done", library).click()
        openExport(library)
        type("1200", into: "library.export.longEdge", library)
        type("70", into: "library.export.quality", library)
        sheetButton("Save as Preset…", library).click()
        library.app.typeText("Web 1200\r")
        sheetButton("Cancel", library).click()
        XCTAssert(Self.wait(10) { Self.text(library.element("library.catalog")) == "saved" },
                  "the catalog never read saved")
        library.app.terminate()

        // Step 4: relaunch on the same catalog: the last settings and "Web 1200" come back.
        library = Journey("Library", self, arguments: arguments)
        waitForGrid(library)
        cell("IMG_0001", library).click()
        openExport(library)
        XCTAssertEqual(Self.text(library.element("library.export.longEdge")), "1200", "the last long edge")
        XCTAssertEqual(Self.text(library.element("library.export.quality")), "70", "the last quality")
        XCTAssertEqual(Self.text(library.element("library.export.name")), "{date}-{seq}", "the last name template")
        let preset = library.element("library.export.preset")
        preset.click()
        XCTAssert(library.app.menuItems["Web 1200"].waitForExistence(timeout: 3), "no Web 1200 in the preset menu")
        library.press(.escape)

        // Step 5: an unknown token disables Export with its reason.
        type("{nope}", into: "library.export.name", library)
        let reason = "Unknown token {nope}."
        let probe = library.element("library.controls")
        let controls = probe.waitForExistence(timeout: 5)
            ? (try? JSONDecoder().decode(ControlDocument.self, from: Data(probe.label.utf8)))?.controls ?? [] : []
        XCTAssert(controls.contains { !$0.enabled && $0.reason == reason },
                  "no disabled control in library.controls says \"\(reason)\"")
        XCTAssertFalse(sheetButton("Export", library).isEnabled, "Export is enabled with an unknown token")
        library.app.terminate()
    }

    // MARK: - Helpers

    /// The window and IMG_0024's cell: the import and the catalog are ready.
    @MainActor private func waitForGrid(_ library: Journey) {
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(cell("IMG_0024", library).waitForExistence(timeout: 60), "no grid cell for IMG_0024")
    }

    /// View > Sort By > Name.
    @MainActor private func sortByName(_ library: Journey) {
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let sort = view.menuItems["Sort By"]
        XCTAssert(sort.waitForExistence(timeout: 3), "the View menu has no Sort By")
        sort.hover()
        sort.menuItems["Name"].click()
    }

    /// File > Export…, then the sheet.
    @MainActor private func openExport(_ library: Journey) {
        let file = library.app.menuBars.firstMatch.menuBarItems["File"]
        file.click()
        file.menuItems["Export…"].click()
        XCTAssert(library.app.sheets.firstMatch.waitForExistence(timeout: 5), "File > Export… opened no sheet")
    }

    /// The preset menu's item `name`.
    @MainActor private func choosePreset(_ name: String, _ library: Journey) {
        let preset = library.element("library.export.preset")
        XCTAssert(preset.waitForExistence(timeout: 3), "no library.export.preset")
        preset.click()
        library.app.menuItems[name].click()
    }

    /// Replaces the field `identifier`'s text with `text` and commits it.
    @MainActor private func type(_ text: String, into identifier: String, _ library: Journey) {
        let field = library.element(identifier)
        XCTAssert(field.waitForExistence(timeout: 3), "no \(identifier)")
        field.click()
        library.press(character: "a", .command)
        library.app.typeText(text)
        library.press(.tab)
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

    /// Polls `condition` every 0.1 s for up to `seconds`.
    @MainActor private static func wait(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while Date() < deadline, !condition() { Thread.sleep(forTimeInterval: 0.1) }
        return condition()
    }

    /// What an element reads: its value where macOS puts a field's text, else its label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }
}
