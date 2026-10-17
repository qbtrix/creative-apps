// FlareJourneyTests+Files.swift: step 7 of draw-key-save (DK-12;
// docs/blueprints/flare/features/draw-key-save.md), save and reopen. On
// `-FlareFixture bounce` with `-FlareSaveTo <tmp>`, the toolbar's Save writes
// <tmp>/Untitled.flare with no panel (a JSON object, pretty-printed), and the
// window reads "Untitled", not edited. A relaunch with `-FlareOpenFile` on
// that file brings back Ball, Shadow and Background in the sidebar's LAYERS
// under the title "Untitled". Last, an edit (New Layer) then Save into a
// folder the test made read-only shows the save alert, and the window stays
// edited. XCUITest reads no edited dot, so the hidden `flare.file` element's
// label carries it ("Edited" or "Saved"). Every file lives in this test's own
// temp folder. One shot per step, `flare-files-<step>`.
import XCTest

final class FlareFileJourneys: XCTestCase {
    @MainActor func testSaveAndReopen() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "flare-files-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let locked = folder.appending(path: "Locked")
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
            try? FileManager.default.removeItem(at: folder)
        }
        let file = folder.appending(path: "Untitled.flare")

        // 1. Save on bounce: written without a panel, titled Untitled, not edited.
        var flare = launch(["-FlareFixture", "bounce", "-FlareSaveTo", folder.path])
        save(flare)
        XCTAssert(waitFor { FileManager.default.fileExists(atPath: file.path) }, "Save wrote no \(file.path)")
        let bytes = try Data(contentsOf: file)
        let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        XCTAssertNotNil(object, "the saved file isn't a JSON object")
        expectTitle("Untitled", flare)
        expectStatus("Saved", flare)
        flare.shot("files-1-saved")
        quit(flare)

        // 2. Relaunch on the file: Ball, Shadow and Background are back.
        flare = launch(["-FlareOpenFile", file.path])
        let sidebar = flare.element("suite.sidebar")
        for layer in ["Ball", "Shadow", "Background"] {
            XCTAssert(sidebar.staticTexts[layer].waitForExistence(timeout: 15), "LAYERS has no \(layer) after reopening")
        }
        expectTitle("Untitled", flare)
        expectStatus("Saved", flare)
        flare.shot("files-2-reopened")
        quit(flare)

        // 3. An edit, then Save into a read-only folder: the alert, still edited.
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        flare = launch(["-FlareFixture", "bounce", "-FlareSaveTo", locked.path])
        let newLayer = flare.element("suite.sidebar").buttons["New Layer"]
        XCTAssert(newLayer.waitForExistence(timeout: 10), "the sidebar has no New Layer")
        newLayer.click()
        expectStatus("Edited", flare)
        flare.shot("files-3-edited")
        save(flare)
        let failed = alert(flare)
        let message = failed.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@",
                        "Flare couldn't save this animation", "Flare couldn't save this animation")).firstMatch
        XCTAssert(message.waitForExistence(timeout: 10), "a read-only save showed no save alert")
        flare.shot("files-3-save-alert")
        failed.buttons["OK"].click()
        XCTAssertFalse(FileManager.default.fileExists(atPath: locked.appending(path: "Untitled.flare").path))
        expectStatus("Edited", flare)
        flare.shot("files-3-still-edited")
    }

    // MARK: - Helpers

    @MainActor private func launch(_ arguments: [String]) -> Journey {
        let flare = Journey("Flare", self, arguments: arguments)
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        return flare
    }

    /// The toolbar's Save, clicked as a person would.
    @MainActor private func save(_ flare: Journey) {
        let button = flare.app.toolbars.firstMatch.buttons["flare.file.save"]
        XCTAssert(button.waitForExistence(timeout: 10) && waitFor { button.isEnabled }, "Save is missing or disabled")
        button.click()
    }

    /// ⌘Q; waits for the process to end. A clean document quits without asking.
    @MainActor private func quit(_ flare: Journey) {
        flare.press(character: "q", .command)
        if !flare.app.wait(for: .notRunning, timeout: 15) { flare.app.terminate() }
    }

    @MainActor private func expectTitle(_ title: String, _ flare: Journey) {
        let window = flare.app.windows.firstMatch
        XCTAssert(waitFor { window.title == title }, "the window is titled \(window.title), not \(title)")
    }

    /// `flare.file`'s label: "Edited" while the dot shows, else "Saved".
    @MainActor private func expectStatus(_ status: String, _ flare: Journey) {
        let element = flare.element("flare.file")
        XCTAssert(waitFor { element.label == status }, "flare.file reads \(element.label), not \(status)")
    }

    @MainActor private func alert(_ flare: Journey) -> XCUIElement {
        let sheet = flare.app.sheets.firstMatch
        return sheet.waitForExistence(timeout: 10) ? sheet : flare.app.dialogs.firstMatch
    }

    private func waitFor(seconds: Int = 10, _ condition: () -> Bool) -> Bool {
        for _ in 0..<(seconds * 10) {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }
}
