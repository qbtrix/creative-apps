// LibraryJourneyTests+Shell.swift: the spine's shell journeys (packet
// docs/blueprints/library/features/spine.md, Journey steps). J0 launches on
// a fresh, empty `-LibraryCatalogDir` with no fixture, so the live services
// run: the empty state shows "No Photos" with Import Folder… as its one
// button, and the File and Edit menus agree with `library.controls` (the
// window's hidden JSON list of its controls, SuiteUI's ControlDocument).
// A disabled control's reason is its help tag, read by hovering it.
import XCTest

final class LibraryShellJourneyTests: XCTestCase {
    /// J0: an empty catalog shows its empty state, and File and Edit offer
    /// only what can act.
    @MainActor func testLaunchShowsEmptyCatalog() throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "library-j0-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let library = Journey("Library", self, arguments: ["-LibraryCatalogDir", folder.path])
        library.expectWindowShell()
        library.shot("empty")

        // Step 1: "No Photos" with Import Folder… as its one button, every sidebar count 0.
        let window = library.app.windows.firstMatch
        XCTAssert(Self.text("No Photos", in: window).waitForExistence(timeout: 10), "no \"No Photos\" empty state")
        let button = library.element("library.import")
        XCTAssert(button.waitForExistence(timeout: 5), "no Import Folder… button (library.import)")
        XCTAssertEqual(button.label, "Import Folder…", "the empty state's button")
        XCTAssertEqual(window.buttons.matching(identifier: "library.import").count, 1, "more than one Import Folder…")
        XCTAssertFalse(window.buttons["Load Sample Photos"].exists, "Load Sample Photos is a button, not only in File")
        let counts = library.element("suite.sidebar").staticTexts
            .matching(NSPredicate(format: "label MATCHES %@", "[1-9][0-9]*"))
        XCTAssertEqual(counts.count, 0, "a sidebar count isn't 0")

        // Step 2: File agrees with library.controls; a disabled import says why.
        let entry = Self.decode(library.element("library.controls"))?.controls.first { $0.id == "library.import" }
        let entryEnabled = try XCTUnwrap(entry, "library.controls doesn't list library.import").enabled
        let file = Self.open("File", library)
        library.shot("file-menu-empty", screen: true)
        let importItem = file.menuItems["Import Folder…"]
        XCTAssert(importItem.waitForExistence(timeout: 3), "the File menu has no Import Folder…")
        XCTAssertEqual(importItem.isEnabled, entryEnabled, "File > Import Folder… disagrees with library.controls")
        let export = file.menuItems["Export…"]
        XCTAssert(export.waitForExistence(timeout: 3), "the File menu has no Export…")
        XCTAssertFalse(export.isEnabled, "File > Export… is enabled on an empty catalog")
        library.press(.escape)
        XCTAssertEqual(button.isEnabled, entryEnabled, "Import Folder… disagrees with library.controls")
        if !entryEnabled {
            let reason = entry?.reason ?? ""
            XCTAssertFalse(reason.isEmpty, "a disabled library.import has no reason")
            XCTAssertEqual(reason, "Import isn't connected yet (import).", "library.import's reason")
            button.hover()
            let tag = library.app.helpTags.matching(
                NSPredicate(format: "label CONTAINS %@ OR title CONTAINS %@ OR value CONTAINS %@", reason, reason, reason))
            XCTAssert(tag.firstMatch.waitForExistence(timeout: 5), "Import Folder… doesn't say \(reason)")
        }

        // Step 3: nothing to undo or redo on launch.
        let edit = Self.open("Edit", library)
        for title in ["Undo", "Redo"] {
            let item = edit.menuItems[title]
            XCTAssert(item.waitForExistence(timeout: 3), "the Edit menu has no plain \(title)")
            XCTAssertFalse(item.isEnabled, "Edit > \(title) is enabled on launch")
        }
        library.press(.escape)
    }

    /// Opens the menu bar's `title` menu and returns it.
    @MainActor private static func open(_ title: String, _ library: Journey) -> XCUIElement {
        let menu = library.app.menuBars.firstMatch.menuBarItems[title]
        XCTAssert(menu.waitForExistence(timeout: 5), "no \(title) menu")
        menu.click()
        _ = menu.menuItems.firstMatch.waitForExistence(timeout: 3)
        return menu
    }

    /// The first static text under `root` that reads `text`.
    @MainActor private static func text(_ text: String, in root: XCUIElement) -> XCUIElement {
        root.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", text, text)).firstMatch
    }

    /// The ControlDocument in `probe`'s label; nil when it's missing or isn't one.
    @MainActor private static func decode(_ probe: XCUIElement) -> ControlDocument? {
        guard probe.waitForExistence(timeout: 5) else { return nil }
        return try? JSONDecoder().decode(ControlDocument.self, from: Data(probe.label.utf8))
    }
}
