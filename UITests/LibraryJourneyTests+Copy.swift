// LibraryJourneyTests+Copy.swift: LJ-CB, Library's Copy out to other apps (packet
// docs/blueprints/suiteui/features/clipboard-interop.md, slice CB-library). Live: two 640 × 480 JPEGs
// `LibraryFiles.write` makes, imported on launch into a fresh `-LibraryCatalogDir`. Select one, Edit > Copy:
// the general pasteboard holds a PNG at the photo's full size and a file URL to a clean PNG copy (not the
// original file) that carries no GPS.
//
// Written before its code (clipboard-interop CB-11, skipped); CB-12, which adds `edit.copy` to Library's
// catalog and Edit menu, sets `copyWaitsOn` to nil.
import AppKit
import ImageIO
import XCTest

extension LibraryJourneyTests {
    /// The slice LJ-CB waits on; CB-12 sets it to nil.
    private static let copyWaitsOn: String? = nil

    /// LJ-CB: select a photo, Edit > Copy; the pasteboard holds a PNG and a file URL (`edit-copy-photo`).
    @MainActor func testCopyPhotoOut() throws {
        if let waitsOn = Self.copyWaitsOn { throw XCTSkip("waits on \(waitsOn)") }
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, catalog] { try? FileManager.default.removeItem(at: url) } }
        let originals = try LibraryFiles.write(2, in: folder)
        let library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path, "-LibraryImportOnLaunch",
        ])
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let cell = copyCell("jpeg-0001", library)
        XCTAssert(cell.waitForExistence(timeout: 60), "no grid cell for jpeg-0001")

        // Step 1: select the photo, Edit > Copy.
        let pasteboard = NSPasteboard.general
        _ = pasteboard.clearContents()
        cell.click()
        let edit = library.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let copy = edit.menuItems["Copy"]
        XCTAssert(copy.waitForExistence(timeout: 5), "Edit has no Copy")
        XCTAssert(copy.isEnabled, "Edit > Copy is off with a photo selected")
        copy.click()

        // Step 2: a PNG at the photo's full size.
        XCTAssert(copyLands(within: 10) { pasteboard.data(forType: .png) != nil }, "Copy put no PNG on the pasteboard")
        let png = try XCTUnwrap(pasteboard.data(forType: .png))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: png), "the PNG doesn't decode")
        XCTAssertEqual(bitmap.pixelsWide, 640, "the PNG isn't the photo's full width")
        XCTAssertEqual(bitmap.pixelsHigh, 480, "the PNG isn't the photo's full height")

        // Step 3: a file URL to a clean copy, not the original, with no GPS.
        let urlString = try XCTUnwrap(pasteboard.string(forType: .fileURL), "Copy put no file URL on the pasteboard")
        let url = try XCTUnwrap(URL(string: urlString))
        XCTAssertFalse(originals.map(\.standardizedFileURL).contains(url.standardizedFileURL),
                       "the file URL names the original photo")
        XCTAssert(FileManager.default.fileExists(atPath: url.path), "the file URL names no file: \(url.path)")
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil), "the copied file doesn't open")
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary], "the copied file carries GPS")
        library.shot("edit-copy-photo")
        library.app.terminate()
    }

    /// Whether `condition` holds before `seconds` pass: the copy renders off the main actor.
    @MainActor private func copyLands(within seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() {
            if Date() > deadline { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return true
    }

    /// The grid cell `library.grid.cell.<id>` whose photo id names `name`.
    @MainActor private func copyCell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }
}
