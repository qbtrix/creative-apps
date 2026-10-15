// HaloJourneyTests+Files.swift: H-J10, save and reopen (history-files,
// HF-12; docs/blueprints/halo/features/history-files.md, Journey steps 2).
// On `-HaloSample two-comps` (live services) with `-HaloSaveTo`, ⌘S writes
// Spot.halo with no panel; a relaunch with `-HaloOpenFile` brings Intro and
// Outro back (each composition's `halo.layer.row.<id>` rows, the inspector
// header, the status bar's layer readout and Ball's timeline lane match the
// fixture) with Edit > Undo disabled. XCUITest reads SwiftUI accessibility
// values as empty (#262), so everything here is read by label, identifier or
// existence: `halo.file` carries the save status as its label. Ball's three
// keys surviving the file are proven by HaloFileValidationTests'
// everyFixturePassesTheChecks, and Undo's "Nothing to undo." help by
// HaloHistoryCommandTests (help tags on menu items don't read reliably).
// An edit reads "Edited"; Open Recent > Spot asks to save, Don't Save
// reopens the saved file. Then `huge` is saved and reopened: the first shot
// after that launch has the `halo.file.progress` row (HB-U5), then the
// readout reads "2000 layers". Last, a save into a folder the test made
// read-only shows the save alert and `halo.file` reads "Not saved". Every
// file lives in this test's own temp folder, passed by absolute path. One
// shot per step, `halo-files-<step>`.
import XCTest

final class HaloFilesJourneyTests: XCTestCase {
    /// H-J10: save, quit, reopen, Open Recent, a large open and a failed save.
    @MainActor func testSaveAndReopen() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "halo-files-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let spot = folder.appending(path: "Spot.halo").path
        let locked = folder.appending(path: "Locked")
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
            try? FileManager.default.removeItem(at: folder)
        }

        // 1. ⌘S on two-comps: written without a panel, titled Spot, Saved.
        var halo = launch(["-HaloSample", "two-comps", "-HaloSaveTo", spot])
        halo.press(character: "s", .command)
        expectTitle("Spot", halo)
        expectStatus("Saved", halo)
        XCTAssert(FileManager.default.fileExists(atPath: spot), "⌘S wrote no \(spot)")
        halo.shot("files-1-saved")
        quit(halo)

        // 2. Relaunch on the file: Intro and Outro are back, nothing to undo.
        halo = launch(["-HaloOpenFile", spot])
        expectTitle("Spot", halo)
        expectStatus("Saved", halo)
        XCTAssert(sidebarRow("Intro", halo).exists && sidebarRow("Outro", halo).exists, "Intro and Outro aren't back")
        expectHeader("Intro", halo)
        // Title, Badge, Background and Rig, by the fixture's ids.
        expectLayerRows(["comp-1-layer-4", "comp-1-layer-3", "comp-1-layer-2", "comp-1-layer-1"], halo)
        expectReadout("4 layers", halo)
        sidebarRow("Outro", halo).click()
        expectHeader("Outro", halo)
        XCTAssert(waitFor { !halo.element("halo.layer.row.comp-1-layer-4").exists }, "Intro's rows stayed in Outro")
        // Ball and Floor.
        expectLayerRows(["comp-2-layer-2", "comp-2-layer-1"], halo)
        expectReadout("2 layers", halo)
        let lane = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.timeline.track' AND label == 'Ball'")).firstMatch
        XCTAssert(lane.waitForExistence(timeout: 5), "no Ball lane in Outro's timeline")
        expectUndoDisabled(halo)
        halo.element("halo.layer.row.comp-2-layer-2").click()
        let ball = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.inspector.header' AND label CONTAINS %@", "Frames 0–47")).firstMatch
        XCTAssert(ball.waitForExistence(timeout: 5), "Ball didn't come back with its frames 0–47")
        XCTAssert(ball.label.hasPrefix("Ball"), "the inspector header reads \(ball.label), not Ball")
        halo.shot("files-2-reopened")

        // 3. New Composition…, Create: Edited.
        halo.element("halo.composition.new").click()
        halo.click("Create", in: .sheet)
        expectStatus("Edited", halo)
        halo.shot("files-3-edited")

        // 4. File > Open Recent > Spot asks first; Don't Save reopens the file.
        openRecent("Spot", halo)
        let ask = alert(halo)
        XCTAssert(
            text("Save changes to Spot?", in: ask).waitForExistence(timeout: 5), "no Save changes to Spot? alert")
        halo.shot("files-4-unsaved-alert")
        ask.buttons["Don't Save"].click()
        expectStatus("Saved", halo)
        XCTAssert(waitFor { !self.sidebarRow("Comp 3", halo).exists }, "Don't Save kept the new composition")
        XCTAssert(sidebarRow("Intro", halo).exists && sidebarRow("Outro", halo).exists, "Spot didn't reopen")
        expectTitle("Spot", halo)
        halo.shot("files-4-reopened")
        quit(halo)

        // 5. Save huge, quit, reopen: the progress row in the first shot, then 2000 layers.
        let huge = folder.appending(path: "Huge.halo").path
        halo = launch(["-HaloSample", "huge", "-HaloSaveTo", huge])
        halo.press(character: "s", .command)
        expectStatus("Saved", halo, timeout: 60)
        quit(halo)
        halo = launch(["-HaloOpenFile", huge])
        let progress = halo.element("halo.file.progress")
        XCTAssert(progress.waitForExistence(timeout: 30), "no progress row (halo.file.progress) while Huge opens")
        let opening = progress.label
        halo.shot("files-5-opening")
        XCTAssertEqual(opening, "Opening Huge…", "the progress row's label")
        expectReadout("2000 layers", halo, timeout: 120)
        XCTAssertFalse(progress.exists, "the progress row outlived the open")
        halo.shot("files-5-huge")
        quit(halo)

        // 6. Save into a read-only folder: the alert, then Not saved.
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        halo = launch(["-HaloSample", "two-comps", "-HaloSaveTo", locked.appending(path: "Spot.halo").path])
        halo.element("halo.composition.new").click()
        halo.click("Create", in: .sheet)
        expectStatus("Edited", halo)
        halo.press(character: "s", .command)
        let failed = alert(halo)
        XCTAssert(
            text("Spot.halo can't be saved.", in: failed).waitForExistence(timeout: 5), "a read-only save showed no alert")
        halo.shot("files-6-save-alert")
        failed.buttons["OK"].click()
        expectStatus("Not saved", halo)
        halo.shot("files-6-not-saved")
    }

    // MARK: - Helpers

    /// Launches Halo at 1280 by 800 (narrower drops the status bar's layer
    /// readout) and waits for its window.
    @MainActor private func launch(_ arguments: [String]) -> Journey {
        let halo = Journey("Halo", self, arguments: arguments + ["-HaloWindowSize", "1280x800"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        return halo
    }

    /// ⌘Q, as a person quits; waits for the process to end.
    @MainActor private func quit(_ halo: Journey) {
        halo.press(character: "q", .command)
        if !halo.app.wait(for: .notRunning, timeout: 15) { halo.app.terminate() }
    }

    /// The window's title reads `title`.
    @MainActor private func expectTitle(_ title: String, _ halo: Journey) {
        let window = halo.app.windows.firstMatch
        XCTAssert(waitFor { window.title == title }, "the window is titled \(window.title), not \(title)")
    }

    /// `halo.file`'s label reads `status` (its value reads empty, #262).
    @MainActor private func expectStatus(_ status: String, _ halo: Journey, timeout: Int = 5) {
        let file = halo.element("halo.file")
        XCTAssert(waitFor(seconds: timeout) { file.label == status }, "halo.file reads \(file.label), not \(status)")
    }

    /// The inspector header names composition `name`: it is the selected one.
    @MainActor private func expectHeader(_ name: String, _ halo: Journey) {
        let header = halo.element("halo.inspector.header")
        XCTAssert(
            waitFor(seconds: 30) { header.label.hasPrefix(name) }, "the inspector header reads \(header.label), not \(name)")
    }

    /// The layer list has a `halo.layer.row.<id>` row for each of `ids`.
    @MainActor private func expectLayerRows(_ ids: [String], _ halo: Journey) {
        for id in ids {
            XCTAssert(halo.element("halo.layer.row.\(id)").waitForExistence(timeout: 5), "no layer row \(id)")
        }
    }

    /// The status bar's layer readout reads `readout`.
    @MainActor private func expectReadout(_ readout: String, _ halo: Journey, timeout: Int = 30) {
        let found = text(readout, in: halo.app.windows.firstMatch, exactly: true)
        XCTAssert(found.waitForExistence(timeout: TimeInterval(timeout)), "no \(readout) readout in the viewer")
    }

    /// Edit > Undo is disabled. Its "Nothing to undo." help is proven by
    /// HaloHistoryCommandTests: XCUITest doesn't read SwiftUI .help on menu
    /// items reliably.
    @MainActor private func expectUndoDisabled(_ halo: Journey) {
        let undo = menu("Edit", halo).menuItems["Undo"]
        XCTAssert(undo.waitForExistence(timeout: 3), "the Edit menu has no plain Undo after an open")
        XCTAssertFalse(undo.isEnabled, "Edit > Undo is enabled after an open")
        halo.press(.escape)
    }

    /// File > Open Recent ▸, checks `name` is the first entry and clicks it.
    @MainActor private func openRecent(_ name: String, _ halo: Journey) {
        let parent = menu("File", halo).menuItems["Open Recent"]
        XCTAssert(parent.waitForExistence(timeout: 3), "the File menu has no Open Recent")
        parent.hover()
        let first = parent.menus.firstMatch.children(matching: .menuItem).firstMatch
        XCTAssert(first.waitForExistence(timeout: 3), "Open Recent shows no files")
        XCTAssertEqual(first.title, name, "Open Recent's first entry")
        first.click()
    }

    /// Clicks the menu bar's `title` open and returns it.
    @MainActor private func menu(_ title: String, _ halo: Journey) -> XCUIElement {
        let item = halo.app.menuBars.firstMatch.menuBarItems[title]
        XCTAssert(item.waitForExistence(timeout: 5), "no \(title) menu")
        item.click()
        return item
    }

    /// The sidebar's row titled `title`.
    @MainActor private func sidebarRow(_ title: String, _ halo: Journey) -> XCUIElement {
        text(title, in: halo.element("suite.sidebar"), exactly: true)
    }

    /// A system alert: the window's sheet, or a dialog.
    @MainActor private func alert(_ halo: Journey) -> XCUIElement {
        let sheet = halo.app.sheets.firstMatch
        return sheet.waitForExistence(timeout: 10) ? sheet : halo.app.dialogs.firstMatch
    }

    /// The first element under `root` whose label holds `string` (or equals
    /// it), or a static text whose value does: SwiftUI's Text reads as either.
    @MainActor private func text(_ string: String, in root: XCUIElement, exactly: Bool = false) -> XCUIElement {
        let staticText = NSNumber(value: XCUIElement.ElementType.staticText.rawValue)
        let op = exactly ? "==" : "CONTAINS"
        let predicate = NSPredicate(
            format: "label \(op) %@ OR (elementType == %@ AND value \(op) %@)", string, staticText, string)
        return root.descendants(matching: .any).matching(predicate).firstMatch
    }

    /// Whether `condition` holds within `seconds`.
    @MainActor private func waitFor(seconds: Int = 3, _ condition: () -> Bool) -> Bool {
        for _ in 0..<(seconds * 5) {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
