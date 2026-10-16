// LibraryJourneyTests+Cull.swift: J4, cull from the keyboard with undo and
// Auto Advance (packet docs/blueprints/library/features/cull.md, Journey
// steps). Steps 1-7 run twice: on the `shoot` fixture's fakes, then live on
// the 24 JPEGs `LibraryFiles.writeShoot` writes, imported on launch
// (`-LibraryImportOnLaunch`; those shots end `-live`). Step 8 runs on the
// fakes only (`-LibraryFakeMode fail`): a refused rating shows the cull
// notice `library.notice` and changes nothing. A photo's cull state is the
// loupe photo's value (`library.loupe.photo`, ending in its cull summary,
// "3 stars, Picked") or a grid cell's label and value, which name its marks.
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
        let text = "Rating is unavailable in this preview."
        let message = refused.element("library.notice").descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", text, text)).firstMatch
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
        // Step 1: name order, IMG_0001 in the loupe, Auto Advance on.
        openInLoupe("IMG_0001", library)
        XCTAssert(autoAdvanceItem(library).checked, "Metadata > Auto Advance isn't checked on launch")
        library.press(.escape)

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

        // Step 5: with Auto Advance off, 5 rates and stays.
        autoAdvanceItem(library).item.click()
        XCTAssertFalse(autoAdvanceItem(library).checked, "Metadata > Auto Advance stayed checked")
        library.press(.escape)
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
        XCTAssert(cullCell("IMG_0006", library, marked: "Flagged").waitForExistence(timeout: 5), "P didn't pick IMG_0006")
        library.press(character: "u")
        let edit = library.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        XCTAssertEqual(undoItem(in: edit).title, "Undo Clear Flag", "Edit's Undo after U")
        library.press(.escape)
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

    /// Clicks the loupe photo so its keys reach it after a menu.
    @MainActor private func focusLoupe(_ library: Journey) {
        let photo = library.element("library.loupe.photo")
        XCTAssert(photo.waitForExistence(timeout: 5), "no loupe photo (library.loupe.photo)")
        photo.click()
    }

    /// The loupe's readout names `name` and `position` within five seconds.
    @MainActor private func expectPosition(_ name: String, _ position: String, _ library: Journey) {
        let readout = library.element("library.loupe.position")
        var text = ""
        for _ in 0..<25 {
            let value = (readout.value as? String) ?? ""
            text = value.isEmpty ? readout.label : value
            if text.contains(name), text.hasSuffix(position) { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTFail("the loupe reads \"\(text)\", not \(name) at \(position)")
    }

    /// The loupe photo's value: its render state, then its cull summary.
    @MainActor private func cullValue(_ library: Journey) -> String {
        let photo = library.element("library.loupe.photo")
        XCTAssert(photo.waitForExistence(timeout: 5), "no loupe photo (library.loupe.photo)")
        return (photo.value as? String) ?? ""
    }

    /// The loupe photo's value ends `suffix` within five seconds.
    @MainActor private func expectValue(endingWith suffix: String, _ library: Journey) {
        var value = ""
        for _ in 0..<25 {
            value = cullValue(library)
            if value.hasSuffix(suffix) { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTFail("the loupe photo's value is \"\(value)\", not ending \(suffix)")
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

    /// Opens Metadata and returns Auto Advance with whether it shows its
    /// checkmark (selected, or a non-empty, non-zero mark value). Leaves the menu open.
    @MainActor private func autoAdvanceItem(_ library: Journey) -> (item: XCUIElement, checked: Bool) {
        let metadata = library.app.menuBars.firstMatch.menuBarItems["Metadata"]
        metadata.click()
        let item = metadata.menuItems["Auto Advance"]
        XCTAssert(item.waitForExistence(timeout: 3), "the Metadata menu has no Auto Advance")
        XCTAssert(item.isEnabled, "Metadata > Auto Advance is disabled")
        let mark = item.value.map { "\($0)" } ?? ""
        return (item, item.isSelected || !(mark.isEmpty || mark == "0"))
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
