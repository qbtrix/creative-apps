// HaloJourneyTests+History.swift: H-J8, undo and redo every edit
// (history-files, #1037; docs/blueprints/halo/features/history-files.md,
// Journey steps). On the `empty` sample (one composition, Comp 1, on live
// services) it adds a solid, renames the composition Intro in the sidebar,
// finds Composition > Delete off with one left, adds Comp 2 from the sheet,
// deletes Intro, then ⌘Z, ⌘Z and ⇧⌘Z. After each edit the Edit menu's first
// item names the step; a timeline scrub in between adds none. The sidebar is
// read by its row titles top first, the selected composition by the
// inspector header (`halo.inspector.header`), the layer count by the status
// bar's readout (`layerSummary`, "1 layer"). A disabled item's reason is its
// help tag, read by hovering it. One shot per step, `halo-history-<step>`.
import XCTest

final class HaloHistoryJourneyTests: XCTestCase {
    /// H-J8: every composition and new-layer edit undone and redone from the keyboard.
    @MainActor func testUndoRedoEveryEdit() {
        // 1280 wide, so the status bar keeps its layer count.
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "empty", "-HaloWindowSize", "1280x800"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        expectSidebar(["Comp 1"], halo)

        // 1. Layer > New > Solid.
        choose(["Layer", "New", "Solid"], halo)
        XCTAssert(text("Solid 1", in: halo.element("halo.layer.list")).waitForExistence(timeout: 5), "no Solid 1 row")
        expectUndo("Undo New Layer", halo)
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
        expectDisabled(["Composition", "Delete"], help: "A project keeps at least one composition.", halo)
        halo.shot("history-4-delete-disabled")

        // 5. Composition > New, Create: Comp 2 below Intro, selected.
        choose(["Composition", "New"], halo)
        halo.click("Create", in: .sheet)
        expectSidebar(["Intro", "Comp 2"], halo)
        expectSelected("Comp 2", halo)
        expectUndo("Undo New Composition", halo)
        halo.shot("history-5-new-composition")

        // 6. Select Intro (not a step).
        text("Intro", in: sidebar).click()
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
        XCTAssert(text("1 layer", in: halo.app.windows.firstMatch).waitForExistence(timeout: 5), "the readout isn't 1 layer")
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

    /// The menu item at `path` is disabled and its help tag reads `help`.
    @MainActor private func expectDisabled(_ path: [String], help: String, _ halo: Journey) {
        let item = menuItem(path, halo)
        XCTAssertFalse(item.isEnabled, "\(path.joined(separator: " > ")) is enabled")
        item.hover()
        let tag = halo.app.helpTags.matching(
            NSPredicate(format: "label CONTAINS %@ OR title CONTAINS %@ OR value CONTAINS %@", help, help, help))
        XCTAssert(tag.firstMatch.waitForExistence(timeout: 5), "\(path.joined(separator: " > ")) doesn't say \(help)")
        halo.press(.escape)
    }

    /// The Edit menu's first item reads `title`; the menu is closed again.
    @MainActor private func expectUndo(_ title: String, _ halo: Journey) {
        let edit = menuItem(["Edit"], halo)
        let first = edit.menus.firstMatch.children(matching: .menuItem).firstMatch
        XCTAssert(first.waitForExistence(timeout: 3), "the Edit menu shows no items")
        XCTAssertEqual(first.title, title, "the Edit menu's first item")
        halo.press(.escape)
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
