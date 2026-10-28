// LibraryJourneyTests+Looks.swift: the Develop tab's LOOKS and BLACK & WHITE
// (adjust-everywhere AJ-11, packet docs/blueprints/suiteui/features/
// adjust-everywhere.md). On the 24 solid-colour JPEGs `LibraryFiles.writeShoot`
// writes, imported on launch: three photos selected, the built-in Black & White
// look (`suite.looks.look.bw`) clicked once turns their cells and the loupe
// grey, and one Undo gives all three their colour back. Grey is read off each
// element's screenshot: the centre pixel's channels within a few levels of each
// other.
import AppKit
import XCTest

final class LibraryLooksJourneyTests: XCTestCase {
    /// Select IMG_0001 to IMG_0003, click the B&W look, see grey grid cells and loupe, undo once.
    @MainActor func testBlackAndWhiteLook() throws {
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, catalog] { try? FileManager.default.removeItem(at: url) } }
        _ = try LibraryFiles.writeShoot(in: folder)
        let library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path,
            "-LibraryImportOnLaunch", "-LibraryTestValues",
        ])
        sortByName(library)
        let names = ["IMG_0001", "IMG_0002", "IMG_0003"]
        cell(names[0], library).click()
        XCUIElement.perform(withKeyModifiers: .shift) { cell(names[2], library).click() }
        XCTAssert(wait(5) { names.allSatisfy { !self.isGrey(self.cell($0, library)) } }, "the shoot's cells aren't colourful")
        developTab(library)
        let look = library.element("suite.looks.look.bw")
        XCTAssert(look.waitForExistence(timeout: 5), "no Black & White look (suite.looks.look.bw)")
        XCTAssert(library.element("library.develop.bw").exists, "no BLACK & WHITE checkbox (library.develop.bw)")
        look.click()
        library.shot("looks-bw-grid")
        for name in names {
            XCTAssert(wait(10) { self.isGrey(self.cell(name, library)) }, "\(name)'s cell didn't go grey")
        }
        XCTAssertFalse(isGrey(cell("IMG_0004", library)), "the look reached IMG_0004, outside the selection")
        expectUndo("Undo Apply Look", library)
        cell(names[0], library).doubleClick()
        let loupe = library.element("library.loupe.photo")
        XCTAssert(loupe.waitForExistence(timeout: 10), "double-click didn't open the loupe")
        XCTAssert(wait(10) { self.isGrey(loupe) }, "the loupe didn't draw IMG_0001 grey")
        library.shot("looks-bw-loupe")
        library.press(.escape)
        library.press(character: "z", .command)
        for name in names {
            XCTAssert(wait(10) { !self.isGrey(self.cell(name, library)) }, "one Undo left \(name) grey")
        }
        library.shot("looks-bw-undone")
        library.app.terminate()
    }

    // MARK: - Helpers

    /// True when the centre of `element`'s screenshot is grey: its channels within 6 of 255 apart.
    @MainActor private func isGrey(_ element: XCUIElement) -> Bool {
        guard element.exists, let tiff = element.screenshot().image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff), bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0,
            let colour = bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB)
        else { return false }
        let channels = [colour.redComponent, colour.greenComponent, colour.blueComponent]
        guard let high = channels.max(), let low = channels.min() else { return false }
        return (high - low) * 255 <= 6
    }

    @MainActor private func developTab(_ library: Journey) {
        let tab = library.element("suite.inspector").descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Develop'")).firstMatch
        XCTAssert(tab.waitForExistence(timeout: 5), "the inspector has no Develop tab")
        tab.click()
    }

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

    /// Edit's first item reads `title` ("Undo Apply Look").
    @MainActor private func expectUndo(_ title: String, _ library: Journey) {
        let edit = library.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let undo = edit.menuItems.matching(NSPredicate(format: "title BEGINSWITH 'Undo'")).firstMatch
        XCTAssert(undo.waitForExistence(timeout: 3), "the Edit menu has no Undo")
        XCTAssertEqual(undo.title, title, "Edit's Undo")
        library.press(.escape)
    }
}
