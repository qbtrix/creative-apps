// LibraryJourneyTests+CullFinish.swift: J-DR1 (docs/blueprints/library/features/cull-finish.md, Journey
// steps): label keys 7 and 9 with undo, then Delete Rejected Photos… with Cancel, Move to Trash, Undo,
// Redo and a re-import that finds nothing new, on live services and the live Trash in a scratch folder (DR-9).
import XCTest

final class LibraryCullFinishJourneyTests: XCTestCase {
    @MainActor func testDeleteRejects() throws {
        // Step 1: the shoot, imported live from a scratch folder.
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, catalog] { try? FileManager.default.removeItem(at: url) } }
        try LibraryFiles.writeShoot(in: folder)
        let library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path, "-LibraryImportOnLaunch",
        ])
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let cells = library.app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "library.grid.cell."))
        XCTAssert(cells.firstMatch.waitForExistence(timeout: 20), "the shoot never reached the grid")
        XCTAssertEqual(cells.count, 24, "the shoot isn't 24 photos")

        // Step 2: 7 labels IMG_0005 Yellow; 9 labels three Blue; Undo clears the three.
        let cell = { (name: String) in library.element("library.grid.cell.\(name)") }
        cell("IMG_0005").click()
        library.press(character: "7", step: "label-yellow")
        XCTAssert((cell("IMG_0005").value as? String ?? "").contains("Yellow"), "7 didn't label IMG_0005 Yellow")
        let three = ["IMG_0002", "IMG_0005", "IMG_0008"]
        select(three, cell)
        library.press(character: "9", step: "label-blue")
        for name in three { XCTAssert((cell(name).value as? String ?? "").contains("Blue"), "9 didn't label \(name) Blue") }
        library.press(character: "z", .command, step: "label-undo")
        for name in three { XCTAssertFalse((cell(name).value as? String ?? "").contains("Blue"), "Undo left \(name) Blue") }

        // Reject the three, then Step 3: the confirm; Cancel changes nothing.
        select(three, cell)
        library.press(character: "x", step: "rejected")
        let photo = library.app.menuBars.firstMatch.menuBarItems["Photo"]
        let delete = { () -> XCUIElement in
            photo.click()
            let item = photo.menuItems["Delete 3 Rejected Photos…"]
            XCTAssert(item.waitForExistence(timeout: 5), "Photo has no Delete 3 Rejected Photos…")
            XCTAssert(item.isEnabled, "Delete 3 Rejected Photos… is off with three rejects")
            item.click()
            return library.app.buttons["library.trash.confirm"]
        }
        XCTAssert(delete().waitForExistence(timeout: 5), "Delete Rejected Photos… asked for no confirm")
        let question = library.app.staticTexts["Move 3 rejected photos to the Trash?"]
        XCTAssert(question.exists, "the confirm doesn't ask \"Move 3 rejected photos to the Trash?\"")
        library.shot("delete-rejects-confirm", screen: true)
        library.app.buttons["library.trash.cancel"].click()
        XCTAssertEqual(cells.count, 24, "Cancel changed the grid")

        // Step 4: Move to Trash leaves 21, and their files leave the folder.
        delete().click()
        XCTAssert(wait(10) { cells.count == 21 }, "the grid shows \(cells.count), not 21")
        library.shot("delete-rejects-done")
        for name in three {
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("\(name).jpg").path),
                           "\(name).jpg is still in the folder")
        }

        // Step 5: Undo puts the 24 and their files back.
        library.press(character: "z", .command, step: "delete-rejects-undo")
        XCTAssert(wait(10) { cells.count == 24 }, "Undo left \(cells.count) photos")
        for name in three {
            XCTAssert(FileManager.default.fileExists(atPath: folder.appendingPathComponent("\(name).jpg").path),
                      "Undo didn't put \(name).jpg back")
        }

        // Step 6: Redo, then a re-import of the same folder finds no new photos.
        library.press(character: "z", [.command, .shift], step: "delete-rejects-redo")
        let file = library.app.menuBars.firstMatch.menuBarItems["File"]
        file.click()
        file.menuItems["Import Folder…"].click()
        let none = library.app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "No new photos", "No new photos"))
        XCTAssert(none.firstMatch.waitForExistence(timeout: 10), "the re-import didn't say \"No new photos.\"")
        library.shot("delete-rejects-reimport")
    }

    /// Click the first of `names`, then command-click the rest.
    @MainActor private func select(_ names: [String], _ cell: (String) -> XCUIElement) {
        for (offset, name) in names.enumerated() {
            if offset == 0 { cell(name).click() } else { XCUIElement.perform(withKeyModifiers: .command) { cell(name).click() } }
        }
    }

    /// Polls `done` for up to `seconds`.
    @MainActor private func wait(_ seconds: TimeInterval, until done: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            if done() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return done()
    }
}
