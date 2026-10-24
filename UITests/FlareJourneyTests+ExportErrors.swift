// FlareJourneyTests+ExportErrors.swift: J23 of flare-export (FX-3, steps 1 to
// 3 live in FX-9; docs/blueprints/flare/features/flare-export.md, section 4).
// The first test runs on `-FlareFixture bounce` (scene `scene-1`, 48 frames)
// with the fakes, whose PNG frames step 4 slows to 200 ms each (`-FlareExportFrameDelay`) so the run outlasts
// XCUITest's lookups and Cancel is still there; the second
// runs steps 1 to 3 again on `-FlareSample bounce` (LiveExportAdapter, no frame
// pause, so step 4's Cancel stays on the fakes). Every launch passes
// `-FlareExportTo` on a folder this test makes and removes. A second SVG
// export to the same folder fails in the sheet with the refusal and Try
// Again, leaving the first file's bytes alone; Try Again goes back to editing
// with SVG still chosen and Cancel closes the sheet. A read-only folder named
// Locked fails with "Flare can't write to Locked." and stays empty. Cancel
// during a 2x PNG sequence run closes the sheet and leaves no PNG. One shot per
// step, `flare-export-errors-<step>` (`flare-export-errors-live-<step>` live).
import XCTest

final class FlareExportErrorJourneys: XCTestCase {
    @MainActor func testExportNeverOverwritesCancelAndFailure() throws {
        let fakes = ["-FlareFixture", "bounce"]
        try refuseThenFail(fakes, shot: "export-errors")

        // 4. A fresh folder; PNG sequence; 2x; Export; Cancel within the run: the sheet goes and no PNG is left.
        let fresh = try folder("Fresh")
        // 200 ms a frame: at the fakes' 20 ms the 48 frames finished in under 2 s, before XCUITest's lookups
        // reached Cancel, so the sheet read Done (#3806).
        let flare = launch(fakes + ["-FlareExportFrameDelay", "200"], on: fresh)
        let export = openSheet(flare)
        let chip = flare.element("flare.export.format.pngSequence")
        XCTAssert(chip.waitForExistence(timeout: 5), "the sheet has no PNG sequence chip")
        chip.click()
        let double = flare.element("flare.export.scale.2x")
        XCTAssert(double.waitForExistence(timeout: 5), "the sheet has no 2x chip (flare.export.scale.2x)")
        double.click()
        XCTAssert(Self.waitFor { double.isSelected }, "2x didn't take")
        export.click()
        let cancel = flare.element("flare.export.cancel")
        XCTAssert(flare.element("flare.export.progress").waitForExistence(timeout: 5), "the run showed no progress")
        cancel.click()
        flare.shot("export-errors-4-cancelled")
        XCTAssert(flare.app.sheets.firstMatch.waitForNonExistence(timeout: 10), "Cancel left the sheet open")
        let left = try FileManager.default.contentsOfDirectory(atPath: fresh.path).filter { $0.hasSuffix(".png") }
        XCTAssertEqual(left, [], "Cancel left \(left.sorted())")
    }

    /// J23 steps 1 to 3 live: the refusal, Try Again and the read-only folder on bounce's real services.
    @MainActor func testExportNeverOverwritesAndFailsLive() throws {
        try refuseThenFail(["-FlareSample", "bounce"], shot: "export-errors-live")
    }

    // MARK: - Helpers

    /// Steps 1 to 3 on `source` (the launch flags naming bounce), each shot named `<shot>-<step>`.
    @MainActor private func refuseThenFail(_ source: [String], shot: String) throws {
        // 1. Export SVG, Done, Export… and Export again: refused, the first file untouched.
        let first = try folder("Exports")
        var flare = launch(source, on: first)
        openSheet(flare).click()
        let svg = first.appending(path: "scene-1.svg")
        XCTAssert(Self.waitFor { FileManager.default.fileExists(atPath: svg.path) }, "Export wrote no scene-1.svg")
        let bytes = try Data(contentsOf: svg)
        let done = flare.element("flare.export.dismiss")
        XCTAssert(done.waitForExistence(timeout: 10), "the run never finished (no Done)")
        done.click()
        XCTAssert(flare.app.sheets.firstMatch.waitForNonExistence(timeout: 5), "Done left the sheet open")
        openSheet(flare).click()
        expectLine("scene-1.svg is already in Exports. Choose another folder.", flare)
        let tryAgain = flare.element("flare.export.tryAgain")
        XCTAssert(tryAgain.waitForExistence(timeout: 5), "the failed sheet has no Try Again (flare.export.tryAgain)")
        XCTAssertEqual(try Data(contentsOf: svg), bytes, "the refused export changed scene-1.svg")
        flare.shot("\(shot)-1-refused")

        // 2. Try Again: editing, SVG still chosen; Cancel closes the sheet.
        tryAgain.click()
        let start = flare.element("flare.export.start")
        XCTAssert(Self.waitFor { start.exists && start.isEnabled }, "Try Again didn't go back to editing")
        XCTAssert(flare.element("flare.export.format.svgFrame").isSelected, "Try Again lost the SVG frame choice")
        flare.shot("\(shot)-2-again")
        flare.element("flare.export.cancel").click()
        XCTAssert(flare.app.sheets.firstMatch.waitForNonExistence(timeout: 5), "Cancel left the sheet open")

        // 3. A read-only folder: "Flare can't write to Locked.", nothing in it.
        let locked = try folder("Locked")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        flare = launch(source, on: locked)
        openSheet(flare).click()
        expectLine("Flare can't write to Locked.", flare)
        XCTAssert(flare.element("flare.export.tryAgain").waitForExistence(timeout: 5), "the failure offers no Try Again")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: locked.path), [], "Locked isn't empty")
        flare.shot("\(shot)-3-locked")
    }

    /// A new empty folder named `name`, removed (made writable first) after the test.
    private func folder(_ name: String) throws -> URL {
        let parent = FileManager.default.temporaryDirectory.appending(path: "flare-export-errors-\(UUID().uuidString)")
        let folder = parent.appending(path: name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
            try? FileManager.default.removeItem(at: parent)
        }
        return folder
    }

    /// Flare on `source` (bounce, on the fakes or live), exporting into `folder`.
    @MainActor private func launch(_ source: [String], on folder: URL) -> Journey {
        let flare = Journey("Flare", self, arguments: source + ["-FlareExportTo", folder.path])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        return flare
    }

    /// Clicks the toolbar's Export…; returns the sheet's Export button.
    @MainActor private func openSheet(_ flare: Journey) -> XCUIElement {
        let open = flare.app.toolbars.firstMatch.buttons["flare.export.showSheet"]
        XCTAssert(open.waitForExistence(timeout: 10) && Self.waitFor { open.isEnabled }, "Export… is missing or disabled")
        open.click()
        XCTAssert(flare.app.sheets.firstMatch.waitForExistence(timeout: 10), "Export… showed no sheet")
        let start = flare.element("flare.export.start")
        XCTAssert(start.waitForExistence(timeout: 5) && start.isEnabled, "the sheet has no enabled Export (flare.export.start)")
        return start
    }

    /// The sheet reads `text` within ten seconds.
    @MainActor private func expectLine(_ text: String, _ flare: Journey) {
        // A SwiftUI Text reaches XCUITest as its value, not its label (as the other journeys match).
        let reads = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)
        let line = flare.app.sheets.firstMatch.staticTexts.matching(reads).firstMatch
        XCTAssert(line.waitForExistence(timeout: 10), "the sheet never read \"\(text)\"")
    }

    private static func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }
}
