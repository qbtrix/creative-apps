// LibraryJourneyTests+Shell.swift: the spine's shell journeys (packet
// docs/blueprints/library/features/spine.md, Journey steps). J0 launches on
// a fresh, empty `-LibraryCatalogDir` with no fixture, so the live services
// run: the empty state shows "No Photos" with Import Folder… as its one
// button, and the File and Edit menus agree with `library.controls` (the
// window's hidden JSON list of its controls, SuiteUI's ControlDocument).
// A disabled control's reason is its library.controls entry and the empty
// state's message (the runner shows no help tag on hover). J11
// (QB-F1, mirroring Halo's H-J13) launches on `-LibraryFixture samples
// -SuitePerfProbe`, merges `library.controls` with the `library.*` entries of
// `suite.controls` (which reaches the toolbar, sidebar and inspector columns a
// preference may not leave), expects every identified control on screen but
// the grid's photo cells to be listed, clicks every enabled control (then
// Escape and Command-Z) and checks it changed the window or a value, and that
// every disabled one says why.
import XCTest

final class LibraryShellJourneyTests: XCTestCase {
    /// J0: an empty catalog shows its empty state, and File and Edit offer
    /// only what can act.
    @MainActor func testLaunchShowsEmptyCatalog() throws {
        let folder = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let library = Journey("Library", self, arguments: ["-LibraryCatalogDir", folder.path])
        library.expectWindowShell()

        // Step 1: "No Photos" with Import Folder… as its one button, every sidebar count 0.
        let window = library.app.windows.firstMatch
        XCTAssert(Self.text("No Photos", in: window).waitForExistence(timeout: 10), "no \"No Photos\" empty state")
        let button = library.element("library.import")
        XCTAssert(button.waitForExistence(timeout: 5), "no Import Folder… button (library.import)")
        library.shot("empty")
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
            // The runner shows no help tag on hover, so the reason is proven by
            // library.controls above and the visible message below.
            let hint = "File > Load Sample Photos"
            let message = window.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", hint, hint)).firstMatch
            XCTAssert(message.exists, "the empty state doesn't say why import is off or point to \(hint)")
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

    /// J11 (QB-F1): every enabled control acts, every disabled one says why.
    @MainActor func testEveryControlActsOrSaysWhy() {
        let library = Journey("Library", self, arguments: ["-LibraryFixture", "samples", "-SuitePerfProbe"])
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let pill = library.element("library.status.preview")
        XCTAssert(pill.waitForExistence(timeout: 10), "no Preview data pill on the fakes")
        let frame = library.app.windows.firstMatch.frame
        XCTAssert(frame.contains(pill.frame), "the Preview data pill \(pill.frame) is outside the window \(frame)")
        library.shot("controls")
        let listed = Self.decode(library.element("library.controls"))
        XCTAssertNotNil(listed, "no library.controls JSON")
        let suite = Self.decode(library.element("suite.controls"))?.controls.filter { $0.id.hasPrefix("library.") } ?? []
        var entries: [String: ControlEntry] = [:]
        for entry in suite + (listed?.controls ?? []) { entries[entry.id] = entry }
        XCTAssertFalse(entries.isEmpty, "neither library.controls nor suite.controls lists a library control")
        attach(entries.values.sorted { $0.id < $1.id }, as: "library-controls")
        for id in Self.onScreenControlIDs(library) {
            XCTAssertNotNil(entries[id], "\(id) is on screen but in neither library.controls nor suite.controls")
        }
        for entry in entries.values.sorted(by: { $0.id < $1.id }) {
            guard entry.enabled else {
                XCTAssertFalse((entry.reason ?? "").isEmpty, "\(entry.id) is disabled and doesn't say why")
                continue
            }
            let control = library.element(entry.id)
            XCTAssert(control.waitForExistence(timeout: 5), "\(entry.id) is listed but not on screen")
            let before = library.app.windows.firstMatch.screenshot().pngRepresentation
            let values = Self.values(library)
            Self.target(control).click()
            Thread.sleep(forTimeInterval: 0.5)
            let after = library.app.windows.firstMatch.screenshot().pngRepresentation
            let changed = before != after || values != Self.values(library)
            library.shot("control-\(library.slug(entry.id))")
            XCTAssert(changed, "\(entry.id) is enabled but clicking it changed nothing")
            library.press(.escape)
            library.press(character: "z", .command)
        }
    }

    /// Where to click `control`: a segmented control acts only on a segment
    /// that isn't selected, so its last unselected segment (button or radio
    /// button child); any other control, itself.
    @MainActor private static func target(_ control: XCUIElement) -> XCUIElement {
        let segmented = [.segmentedControl, .radioGroup].contains(control.elementType)
        let segments = control.children(matching: .radioButton).allElementsBoundByIndex
            + (segmented ? control.children(matching: .button).allElementsBoundByIndex : [])
        return segments.last { !$0.isSelected && $0.isEnabled } ?? control
    }

    /// The probes a click may change without changing the shot: the two
    /// control lists' JSON.
    @MainActor private static func values(_ library: Journey) -> [String] {
        ["library.controls", "suite.controls"].map { id in
            let probe = library.element(id)
            return probe.exists ? probe.label : ""
        }
    }

    /// The `library.*` identifiers of the window's buttons, pop-ups, fields,
    /// checkboxes, sliders and rows, but the grid's photo cells
    /// (`library.grid.cell.<id>`): SuiteUI's ThumbnailGrid cells, one per
    /// photo, which act through the grid's selection, as Halo leaves out its
    /// timeline's track names.
    @MainActor private static func onScreenControlIDs(_ library: Journey) -> Set<String> {
        let window = library.app.windows.firstMatch
        let types: [XCUIElement.ElementType] = [.button, .popUpButton, .textField, .checkBox, .slider, .cell]
        var ids = Set<String>()
        for type in types {
            let query = window.descendants(matching: type).matching(NSPredicate(format: "identifier BEGINSWITH 'library.'"))
            for element in query.allElementsBoundByIndex {
                let id = element.identifier
                if !id.hasPrefix("library.grid.cell.") { ids.insert(id) }
            }
        }
        return ids
    }

    /// Attaches `value` as pretty JSON named `name`, kept even when the test passes.
    private func attach(_ value: some Encodable, as name: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let json = try? encoder.encode(value) else { return }
        let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
