// HaloJourneyTests+History.swift: H-J8, undo and redo every edit
// (history-files, #1037; docs/blueprints/halo/features/history-files.md,
// Journey steps). On the `empty` sample (one composition, Comp 1, on live
// services) it adds a solid, renames the composition Intro in the sidebar,
// finds Composition > Delete off with one left, adds Comp 2 from the sheet,
// deletes Intro, then ⌘Z, ⌘Z and ⇧⌘Z. After each edit the Edit menu's first
// item names the step; a timeline scrub in between adds none. The sidebar is
// read by its row titles top first, the selected composition by the
// inspector header (`halo.inspector.header`), the layer count by the
// `halo.layer.row.*` rows in `halo.layer.list`, each matched by label or
// value (XCUITest can read a SwiftUI value as empty, #262). The window is
// 1000 by 640 so it fits CI's 1024 by 768 display (at that width the status
// bar drops its layer readout). After the first edit the title bar's
// subtitle reads Edited. Every menu is closed (not fading) before a shot. A disabled menu item is
// checked as disabled only: XCUITest doesn't read SwiftUI .help on menu items
// reliably, so its reason ("A project keeps at least one composition.") is
// proven by HaloModelTests' HaloCommandTests over HaloAvailability+Composition.
// One shot per step, `halo-history-<step>`.
import AppKit
import XCTest

final class HaloHistoryJourneyTests: XCTestCase {
    /// H-J8: every composition and new-layer edit undone and redone from the keyboard.
    @MainActor func testUndoRedoEveryEdit() {
        // Fits CI's 1024 by 768 display.
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "empty", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        expectSidebar(["Comp 1"], halo)
        expectFitsScreen(halo)

        // 1. Layer > New > Solid.
        choose(["Layer", "New", "Solid"], halo)
        XCTAssert(text("Solid 1", in: halo.element("halo.layer.list")).waitForExistence(timeout: 5), "no Solid 1 row")
        expectUndo("Undo New Layer", halo)
        XCTAssert(subtitle("Edited", halo).waitForExistence(timeout: 5), "the title bar shows no Edited subtitle")
        halo.shot("history-1-new-layer")

        // 2. Double-click Comp 1 in the sidebar, type Intro, Return.
        let sidebar = halo.element("suite.sidebar")
        text("Comp 1", in: sidebar).doubleClick()
        let field = sidebar.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "double-clicking Comp 1 opened no rename field")
        halo.press(character: "a", .command)
        field.typeText("Intro")
        halo.press(.return)
        expectSidebar(["Intro"], halo)
        expectUndo("Undo Rename Composition", halo)
        halo.shot("history-2-rename")

        // 3. Scrub the timeline's ruler: the playhead moves, no step is added.
        halo.drag(on: "halo.timeline", from: CGVector(dx: 0.3, dy: 0.05), to: CGVector(dx: 0.6, dy: 0.05))
        expectUndo("Undo Rename Composition", halo)
        halo.shot("history-3-scrub")

        // 4. Composition > Delete is off with one composition left.
        expectDisabled(["Composition", "Delete"], halo)
        halo.shot("history-4-delete-disabled")

        // 5. Composition > New, Create: Comp 2 below Intro, selected.
        choose(["Composition", "New"], halo)
        halo.click("Create", in: .sheet)
        expectSidebar(["Intro", "Comp 2"], halo)
        expectSelected("Comp 2", halo)
        expectUndo("Undo New Composition", halo)
        halo.shot("history-5-new-composition")

        // 6. Select Intro (not a step).
        select("Intro", in: sidebar)
        expectSelected("Intro", halo)
        expectUndo("Undo New Composition", halo)
        halo.shot("history-6-select")

        // 7. Composition > Delete: only Comp 2 is left.
        choose(["Composition", "Delete"], halo)
        expectSidebar(["Comp 2"], halo)
        expectUndo("Undo Delete Composition", halo)
        halo.shot("history-7-delete")

        // 8. ⌘Z: Intro is back first, selected, with Solid 1.
        halo.press(character: "z", .command)
        expectSidebar(["Intro", "Comp 2"], halo)
        expectSelected("Intro", halo)
        XCTAssert(text("Solid 1", in: halo.element("halo.layer.list")).waitForExistence(timeout: 5), "Intro lost Solid 1")
        XCTAssert(waitFor { self.layerRowCount(halo) == 1 }, "Intro has \(layerRowCount(halo)) layer rows, not 1")
        expectUndo("Undo New Composition", halo)
        halo.shot("history-8-undo-delete")

        // 9. ⌘Z: Comp 2 is gone.
        halo.press(character: "z", .command)
        expectSidebar(["Intro"], halo)
        expectUndo("Undo Rename Composition", halo)
        halo.shot("history-9-undo-new")

        // 10. ⇧⌘Z: Comp 2 is back.
        halo.press(character: "z", [.command, .shift])
        expectSidebar(["Intro", "Comp 2"], halo)
        expectUndo("Undo New Composition", halo)
        halo.shot("history-10-redo")
    }

    // MARK: - Helpers

    /// The first element under `root` whose label is `title`, or a static
    /// text whose value is (a plain Text reads its string as its value).
    @MainActor private func text(_ title: String, in root: XCUIElement) -> XCUIElement {
        root.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR value == %@", title, title)).firstMatch
    }

    /// The sidebar's composition titles, top first (the section header left out).
    @MainActor private func sidebarTitles(_ halo: Journey) -> [String] {
        let texts = halo.element("suite.sidebar").staticTexts.allElementsBoundByIndex
        var seen = Set<String>()
        return texts.sorted { $0.frame.minY < $1.frame.minY }
            .map { $0.label.isEmpty ? ($0.value as? String ?? "") : $0.label }
            .filter { !$0.isEmpty && $0 != "Compositions" && seen.insert($0).inserted }
    }

    /// The sidebar lists exactly `titles`, top first, within three seconds.
    @MainActor private func expectSidebar(_ titles: [String], _ halo: Journey) {
        XCTAssert(waitFor { self.sidebarTitles(halo) == titles }, "the sidebar reads \(sidebarTitles(halo)), not \(titles)")
    }

    /// The inspector shows composition `name`: it is the selected one.
    @MainActor private func expectSelected(_ name: String, _ halo: Journey) {
        let header = halo.element("halo.inspector.header")
        // One element reading "Intro, 1920 × 1080, 30 fps · 10 s".
        XCTAssert(waitFor { header.label.hasPrefix(name) },"the inspector header reads \(header.label), not \(name)")
    }

    /// Opens the menu bar item `path[0]`, hovers each submenu on the way and
    /// returns the last item (the menu stays open).
    @MainActor private func menuItem(_ path: [String], _ halo: Journey) -> XCUIElement {
        var item = halo.app.menuBars.firstMatch.menuBarItems[path.first ?? ""]
        XCTAssert(item.waitForExistence(timeout: 5), "no \(path.first ?? "") menu")
        item.click()
        for (depth, title) in path.dropFirst().enumerated() {
            if depth > 0 { item.hover() }
            item = item.menus.firstMatch.children(matching: .menuItem)[title]
            XCTAssert(item.waitForExistence(timeout: 3), "no \(path.joined(separator: " > "))")
        }
        return item
    }

    /// Clicks the enabled menu item at `path`.
    @MainActor private func choose(_ path: [String], _ halo: Journey) {
        let item = menuItem(path, halo)
        XCTAssert(item.isEnabled, "\(path.joined(separator: " > ")) is disabled")
        item.click()
    }

    /// The menu item at `path` is disabled; the menu is closed again. Its
    /// help text isn't read here (XCUITest doesn't read SwiftUI .help on menu
    /// items reliably): the Model's availability tests prove it.
    @MainActor private func expectDisabled(_ path: [String], _ halo: Journey) {
        let item = menuItem(path, halo)
        XCTAssertFalse(item.isEnabled, "\(path.joined(separator: " > ")) is enabled")
        closeMenu(halo)
    }

    /// The Edit menu's first item reads `title`; the menu is closed again.
    @MainActor private func expectUndo(_ title: String, _ halo: Journey) {
        let edit = menuItem(["Edit"], halo)
        let first = edit.menus.firstMatch.children(matching: .menuItem).firstMatch
        XCTAssert(first.waitForExistence(timeout: 3), "the Edit menu shows no items")
        XCTAssertEqual(first.title, title, "the Edit menu's first item")
        closeMenu(halo)
    }

    /// The window lies inside the main screen, and the sidebar, inspector
    /// and New Composition… button lie inside the window without overlap.
    @MainActor private func expectFitsScreen(_ halo: Journey) {
        let window = halo.app.windows.firstMatch.frame
        if let screen = NSScreen.main?.frame {
            XCTAssert(screen.contains(window), "the window \(window) runs off the screen \(screen)")
        }
        let sidebar = halo.element("suite.sidebar").frame
        let inspector = halo.element("suite.inspector").frame
        let new = halo.element("halo.composition.new").frame
        for (name, frame) in [("sidebar", sidebar), ("inspector", inspector), ("New Composition…", new)] {
            XCTAssert(window.contains(frame), "the \(name) \(frame) runs out of the window \(window)")
        }
        XCTAssertFalse(sidebar.intersects(inspector), "the sidebar overlaps the inspector")
        // A readable minimum, not SuiteUI's SuiteSize.inspectorWidth.min (200):
        // `suite.inspector` measures 192 pt at 1000 by 640 (run 38721434364),
        // SuiteWindow's sizing, filed as #1106.
        XCTAssertGreaterThanOrEqual(inspector.width, 160, "the inspector is squeezed to \(inspector.width) pt")
    }

    /// Selects the sidebar row titled `title` by clicking its blank space,
    /// right of the title: the title label holds SidebarRow's double-click
    /// rename gesture, and a click on it left H-J10's selection unchanged
    /// (run 38721434364). The point lies inside the sidebar, past the title.
    @MainActor private func select(_ title: String, in sidebar: XCUIElement) {
        let label = text(title, in: sidebar)
        XCTAssert(label.waitForExistence(timeout: 5), "no \(title) row in the sidebar")
        let list = sidebar.frame, row = label.frame
        let x = list.maxX - 24
        XCTAssert(x > row.maxX && list.contains(CGPoint(x: x, y: row.midY)), "no blank space right of \(title) in \(list)")
        sidebar.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x - list.minX, dy: row.midY - list.minY)).click()
    }

    /// Escape, then waits until no menu is up, so the next shot shows no
    /// fading menu over the sidebar.
    @MainActor private func closeMenu(_ halo: Journey) {
        halo.press(.escape)
        XCTAssert(halo.app.menus.firstMatch.waitForNonExistence(timeout: 2), "a menu stayed open after Escape")
    }

    /// The number of distinct `halo.layer.row.*` rows in the layer list.
    @MainActor private func layerRowCount(_ halo: Journey) -> Int {
        let rows = halo.element("halo.layer.list").descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "halo.layer.row.")).allElementsBoundByIndex
        return Set(rows.map(\.identifier)).count
    }

    /// The title bar's subtitle reading `status`: a text in the window that
    /// isn't the hidden `halo.file` element.
    @MainActor private func subtitle(_ status: String, _ halo: Journey) -> XCUIElement {
        halo.app.windows.firstMatch.staticTexts.matching(NSPredicate(
            format: "(label == %@ OR value == %@) AND identifier != %@", status, status, "halo.file")).firstMatch
    }

    /// Whether `condition` holds within three seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
