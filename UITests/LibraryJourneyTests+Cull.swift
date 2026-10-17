// LibraryJourneyTests+Cull.swift: J4, cull from the keyboard with undo and
// Auto Advance (packet docs/blueprints/library/features/cull.md, Journey
// steps). Steps 1-7 run twice: on the `shoot` fixture's fakes, then live on
// the 24 JPEGs `LibraryFiles.writeShoot` writes, imported on launch
// (`-LibraryImportOnLaunch`; those shots end `-live`). Step 8 runs on the
// fakes only (`-LibraryFakeMode fail`): a refused rating shows the cull
// notice `library.notice` and changes nothing. The loupe's readout
// (`library.loupe.position`) reads "<name>  ·  <n> of 24  ·  <cull summary>"
// (#1678); a photo's cull state is that summary ("3 stars, Picked"), else
// the loupe photo's value, which ends in it, or a grid cell's label, which
// names its badges ("2 stars", "Flagged"). The photo element
// (`library.loupe.photo`) is drawn only when its pixels decode, so the journey
// clicks the loupe (`library.loupe`) when it is missing and reads the cull
// summary from the readout. In the loupe Escape goes back to the grid, so a
// menu is closed with Escape only while it is on screen (`closeMenu`).
import XCTest

extension LibraryJourneyTests {
    /// J4: rate, pick and reject with single keys while Auto Advance steps
    /// the loupe on; undo restores without moving; the keys act on a grid
    /// selection too; a refused rating says why.
    @MainActor func testCullWithKeysAndAutoAdvance() throws {
        cullSteps(Journey("Library", self, arguments: ["-LibraryFixture", "shoot"]), suffix: "")

        // Step 8 (fakes): a refused rating shows the notice and changes nothing.
        let refused = Journey("Library", self, arguments: ["-LibraryFixture", "shoot", "-LibraryFakeMode", "fail"])
        openInLoupe("IMG_0001", refused)
        let before = cullValue(refused)
        XCTAssert(before.hasSuffix("No stars"), "IMG_0001 starts as \(before), not unrated")
        focusLoupe(refused)
        refused.press(character: "3", step: "cull-refused")
        let text = "Couldn't set the rating: this window shows built-in sample data, not photos on disk. Import a folder to rate your own photos."
        let message = refused.element("library.notice").descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
        XCTAssert(message.waitForExistence(timeout: 10), "the cull notice (library.notice) doesn't read \"\(text)\"")
        XCTAssert(refused.element("library.notice.close").exists, "the cull notice has no close (library.notice.close)")
        let after = cullValue(refused)
        XCTAssert(after.hasSuffix("No stars"), "a refused rating changed the photo's value to \(after)")
        refused.app.terminate()

        // Live: the same steps on real files imported on launch.
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, catalog] { try? FileManager.default.removeItem(at: url) } }
        try LibraryFiles.writeShoot(in: folder)
        cullSteps(Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path, "-LibraryImportOnLaunch",
        ]), suffix: "-live")
    }

    /// J4 steps 1-7 on `library`, each shot's name ending `suffix`.
    @MainActor private func cullSteps(_ library: Journey, suffix: String) {
        // Step 1: name order, IMG_0001 in the loupe, Auto Advance there. XCUITest
        // can't read a menu Toggle's check mark (#1654): step 2 proves it's on.
        openInLoupe("IMG_0001", library)
        _ = autoAdvanceItem(library)
        closeMenu("Metadata", library)
        XCTAssert(
            loupe(library).waitForExistence(timeout: 5),
            "closing the Metadata menu left the loupe (library.loupe); an Escape reached it"
        )

        // Step 2: 3 rates IMG_0001 and moves on to IMG_0002.
        focusLoupe(library)
        library.press(character: "3", step: "cull-rated\(suffix)")
        expectPosition("IMG_0002", "2 of 24", library)
        library.press(.leftArrow)
        expectPosition("IMG_0001", "1 of 24", library)
        expectValue(endingWith: "3 stars", library)
        library.press(.rightArrow)
        expectPosition("IMG_0002", "2 of 24", library)

        // Step 3: P picks IMG_0002, X rejects IMG_0003; one favorite.
        library.press(character: "p")
        expectPosition("IMG_0003", "3 of 24", library)
        library.press(character: "x", step: "cull-flagged\(suffix)")
        expectPosition("IMG_0004", "4 of 24", library)
        expectSidebarCount("Favorites", 1, library)

        // Step 4: Edit > Undo Reject; the loupe stays put (#426).
        clickUndo(named: "Undo Reject", library)
        library.shot("cull-undo\(suffix)")
        expectPosition("IMG_0004", "4 of 24", library)
        focusLoupe(library)
        library.press(.leftArrow)
        expectPosition("IMG_0003", "3 of 24", library)
        XCTAssertFalse(cullValue(library).contains("Rejected"), "IMG_0003 is still rejected after the undo")

        // Step 5: with Auto Advance off, 5 rates and stays. Choosing the item
        // closes the menu, so no Escape here: it would leave the loupe (#1666).
        autoAdvanceItem(library).click()
        focusLoupe(library)
        library.press(character: "5")
        expectValue(endingWith: "5 stars", library)
        expectPosition("IMG_0003", "3 of 24", library)

        // Step 6: in the grid, 2 rates both selected photos; the selection stays.
        library.press(.escape)
        let fifth = cullCell("IMG_0005", library)
        let sixth = cullCell("IMG_0006", library)
        XCTAssert(fifth.waitForExistence(timeout: 10), "no grid cell for IMG_0005")
        fifth.click()
        XCUIElement.perform(withKeyModifiers: .command) { sixth.click() }
        library.press(character: "2", step: "cull-grid\(suffix)")
        for name in ["IMG_0005", "IMG_0006"] {
            let rated = cullCell(name, library, marked: "2 stars")
            XCTAssert(rated.waitForExistence(timeout: 5), "\(name)'s grid cell doesn't read 2 stars")
            XCTAssert(cullCell(name, library).isSelected, "the selection moved off \(name)")
        }

        // Step 7: P picks both, U clears them; Undo names Clear Flag.
        library.press(character: "p")
        for name in ["IMG_0005", "IMG_0006"] {
            XCTAssert(cullCell(name, library, marked: "Flagged").waitForExistence(timeout: 5), "P didn't pick \(name)")
        }
        library.press(character: "u")
        let edit = library.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        XCTAssertEqual(undoItem(in: edit).title, "Undo Clear Flag", "Edit's Undo after U")
        closeMenu("Edit", library)
        library.app.terminate()
    }

    // MARK: - Cull helpers

    /// Waits for the grid, sorts by name, selects `name` and opens View > Loupe.
    @MainActor private func openInLoupe(_ name: String, _ library: Journey) {
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        expectSidebarCount("All Photos", 24, library, timeout: 60)
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let sort = view.menuItems["Sort By"]
        XCTAssert(sort.waitForExistence(timeout: 3), "the View menu has no Sort By")
        sort.hover()
        let byName = sort.menuItems["Name"]
        XCTAssert(byName.waitForExistence(timeout: 3), "View > Sort By has no Name")
        byName.click()
        let cell = cullCell(name, library)
        XCTAssert(cell.waitForExistence(timeout: 10), "no grid cell for \(name)")
        cell.click()
        view.click()
        view.menuItems["Loupe"].click()
        expectPosition(name, "1 of 24", library)
    }

    /// The loupe group (`library.loupe`), there whether or not its photo decoded.
    @MainActor private func loupe(_ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any)["library.loupe"]
    }

    /// Clicks the loupe photo so its keys reach it after a menu, or the loupe
    /// itself when the photo element isn't drawn.
    @MainActor private func focusLoupe(_ library: Journey) {
        let photo = library.element("library.loupe.photo")
        if photo.waitForExistence(timeout: 3) {
            photo.click()
            return
        }
        let group = loupe(library)
        XCTAssert(group.waitForExistence(timeout: 5), "no loupe (library.loupe) to focus")
        group.click()
    }

    /// Whether the menu bar item `title` has its menu on screen: its first
    /// item exists and is hittable, as a closed menu's items aren't.
    @MainActor private func menuShown(_ title: String, _ library: Journey) -> Bool {
        let item = library.app.menuBars.firstMatch.menuBarItems[title].menuItems.firstMatch
        return item.exists && item.isHittable
    }

    /// Closes the menu `title` if it is still on screen. Escape goes only to
    /// an open menu: in the loupe a stray Escape goes back to the grid.
    @MainActor private func closeMenu(_ title: String, _ library: Journey) {
        guard menuShown(title, library) else { return }
        library.press(.escape)
        for _ in 0..<15 where menuShown(title, library) { Thread.sleep(forTimeInterval: 0.2) }
        XCTAssertFalse(menuShown(title, library), "the \(title) menu stayed open after Escape")
    }

    /// The loupe's readout, "<name>  ·  <n> of 24  ·  <cull summary>", and its trimmed parts.
    @MainActor private func readoutParts(_ library: Journey) -> (text: String, parts: [String]) {
        let readout = library.element("library.loupe.position")
        let value = (readout.value as? String) ?? ""
        let text = value.isEmpty ? readout.label : value
        return (text, text.split(separator: "·").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    /// Within five seconds the readout names `name` and has a part that is
    /// exactly `position`, so "1 of 24" never matches "11 of 24".
    @MainActor private func expectPosition(_ name: String, _ position: String, _ library: Journey) {
        var text = ""
        for _ in 0..<25 {
            let read = readoutParts(library)
            text = read.text
            if text.contains(name), read.parts.contains(position) { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTFail("the loupe reads \"\(text)\", not \(name) at \(position)")
    }

    /// The loupe photo's cull summary: the readout's last part, else the
    /// photo's value (its render state, then the summary), which XCUITest
    /// may read empty (#262), else the readout as read. Never requires the
    /// photo element, which isn't drawn when its pixels don't decode.
    @MainActor private func cullValue(_ library: Journey) -> String {
        let read = readoutParts(library)
        if read.parts.count >= 3, let summary = read.parts.last, !summary.isEmpty { return summary }
        let photo = library.element("library.loupe.photo")
        if photo.exists, let value = photo.value as? String, !value.isEmpty { return value }
        return read.parts.last ?? read.text
    }

    /// The loupe photo's cull summary ends `suffix` within five seconds.
    @MainActor private func expectValue(endingWith suffix: String, _ library: Journey) {
        var value = ""
        for _ in 0..<25 {
            value = cullValue(library)
            if value.hasSuffix(suffix) { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTFail("the loupe photo's cull summary is \"\(value)\", not ending \(suffix)")
    }

    /// The grid cell naming `name`, and `marked` in its label or value when given.
    @MainActor private func cullCell(_ name: String, _ library: Journey, marked: String? = nil) -> XCUIElement {
        let cells = library.app.splitGroups.descendants(matching: .button)
            .matching(NSPredicate(format: "label CONTAINS %@", name))
        guard let marked else { return cells.firstMatch }
        return cells.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", marked, marked)).firstMatch
    }

    /// The sidebar row `title` shows `count`.
    @MainActor private func expectSidebarCount(
        _ title: String, _ count: Int, _ library: Journey, timeout: TimeInterval = 10
    ) {
        let rowTypes = [XCUIElement.ElementType.tableRow, .outlineRow, .cell].map { NSNumber(value: $0.rawValue) }
        let row = library.element("suite.sidebar").descendants(matching: .any)
            .matching(NSPredicate(format: "elementType IN %@", rowTypes))
            .containing(NSPredicate(format: "label == %@ OR value == %@", title, title)).firstMatch
        XCTAssert(row.waitForExistence(timeout: 10), "the sidebar has no \(title) row")
        let badge = row.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", "\(count)", "\(count)")).firstMatch
        XCTAssert(badge.waitForExistence(timeout: timeout), "\(title) doesn't count \(count)")
    }

    /// Opens Metadata and returns its enabled Auto Advance. Leaves the menu open.
    @MainActor private func autoAdvanceItem(_ library: Journey) -> XCUIElement {
        let metadata = library.app.menuBars.firstMatch.menuBarItems["Metadata"]
        metadata.click()
        let item = metadata.menuItems["Auto Advance"]
        XCTAssert(item.waitForExistence(timeout: 3), "the Metadata menu has no Auto Advance")
        XCTAssert(item.isEnabled, "Metadata > Auto Advance is disabled")
        return item
    }

    /// Edit's top-level Undo item, whatever step it names.
    @MainActor private func undoItem(in edit: XCUIElement) -> XCUIElement {
        let item = edit.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", "Undo")).firstMatch
        XCTAssert(item.waitForExistence(timeout: 3), "the Edit menu has no Undo")
        return item
    }

    /// Opens Edit, checks its Undo reads `title`, and chooses it.
    @MainActor private func clickUndo(named title: String, _ library: Journey) {
        let edit = library.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let item = undoItem(in: edit)
        XCTAssertEqual(item.title, title, "Edit's Undo item")
        item.click()
    }
}
