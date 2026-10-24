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
// value (XCUITest can read a SwiftUI value as empty, #262), and by the
// status bar's readout ("1 layer"). The window is 1000 by 640 so it fits
// CI's 1024 by 768 display. After the first edit the title bar's
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
        XCTAssert(
            halo.app.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", "1 layer", "1 layer"))
                .firstMatch.waitForExistence(timeout: 5), "the status bar doesn't read 1 layer")
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
        XCTAssert(halo.menusClosed(), "a menu stayed open after Escape")
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

/// J-HA (autosave-history, HA-2 written, HA-7 turned on): the History panel
/// from the transport's History button (`halo.history.show`) jumps back
/// through key edits, and a force-quit's recovery copy comes back. `keyed` is
/// saved as title.halo with autosave off, then reopened; Ball
/// (`comp-1-layer-2`, keyed on x at 0 and 24) gets ten typed Position X
/// values at frames 0 to 9, ten "Change Position X" steps under "Open". The
/// panel is SuiteUI's (`suite.history`, rows `suite.history.row.<n>`, the
/// current one selected); a jump shows on the timeline as Ball's keys
/// (`halo.timeline.key.comp-1-layer-2.<frame>`). Down and Return, then Up and
/// Return, jump from the keyboard. Step 3: the window autosaves to
/// `<support>/Halo/Recovery/` (HaloRecoveryStore, HA-7b) as `halo.main.halo`;
/// the relaunch offers it under the file's name, "title", and Restore puts it
/// in the window through `HaloProject.restoreRecovered`. Shots `halo-history-panel`,
/// `-jumped`, `-keyboard`, `halo-recovery-offer`, `-restored`.
extension HaloHistoryJourneyTests {
    private static let ball = "comp-1-layer-2"

    @MainActor func testJumpAndRecover() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "halo-jump-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let title = folder.appending(path: "title.halo"), support = folder.appending(path: "support")
        let size = ["-HaloWindowSize", "1000x640"], store = ["-SuiteSupportDir", support.path]

        // 1. Save keyed as title.halo, reopen it, make 10 key edits, click History: "Open" and 10 steps.
        var halo = Journey("Halo", self, arguments: size + ["-HaloSample", "keyed", "-HaloSaveTo", title.path])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        halo.press(character: "s", .command)
        XCTAssert(waitFor { FileManager.default.fileExists(atPath: title.path) }, "⌘S wrote no title.halo")
        halo.app.terminate()
        halo = Journey("Halo", self, arguments: size + store + ["-HaloOpenFile", title.path])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let row = halo.element("halo.layer.row.\(Self.ball)")
        XCTAssert(row.waitForExistence(timeout: 10), "title.halo shows no Ball row")
        row.click()
        let track = halo.trackName("Ball")
        XCTAssert(track.waitForExistence(timeout: 10), "no Ball track title in the timeline")
        track.click()
        halo.press(.home)
        for frame in 0..<10 {
            typeX(100 + frame * 10, halo)
            track.click()
            halo.press(.rightArrow)
        }
        expectUndo("Undo Change Position X", halo)
        halo.element("halo.history.show").click()
        XCTAssert(halo.element("suite.history").waitForExistence(timeout: 5), "the History button showed no panel")
        XCTAssert(halo.element("suite.history.row.0").label.hasPrefix("Open"), "the panel's first row isn't Open")
        let ten = halo.element("suite.history.row.10")
        XCTAssert(ten.waitForExistence(timeout: 5), "the panel lists fewer than 10 steps")
        XCTAssertFalse(halo.element("suite.history.row.11").exists, "the panel lists more than 10 steps")
        XCTAssert(ten.isSelected, "the last step isn't current")
        halo.shot("history-panel")

        // 2. Click step 4: Ball keeps its keys at 0 to 3 only, the later steps stay listed, the project reads edited.
        let four = halo.element("suite.history.row.4")
        four.click()
        XCTAssert(waitFor { four.isSelected }, "step 4 isn't current after the click")
        expectKeys(through: 3, halo)
        XCTAssert(ten.exists, "the jump dropped the later steps")
        XCTAssert(subtitle("Edited", halo).waitForExistence(timeout: 5), "the jumped project isn't marked edited")
        halo.shot("history-panel-jumped")

        // Keyboard parity: the click focused the panel; Down and Return jump to step 5, Up and Return back to 4.
        halo.press(.downArrow)
        halo.press(.return)
        let five = halo.element("suite.history.row.5")
        XCTAssert(waitFor { five.isSelected }, "Down and Return didn't jump to step 5")
        expectKeys(through: 4, halo)
        halo.press(.upArrow)
        halo.press(.return)
        XCTAssert(waitFor { four.isSelected }, "Up and Return didn't jump back to step 4")
        expectKeys(through: 3, halo)
        halo.shot("history-panel-keyboard")

        // 3. Quit unsaved once autosaved, relaunch: the offer names title; Restore shows the 4-step project, edited.
        let recovery = support.appending(path: "Halo/Recovery")
        let autosaved = waitFor(seconds: 20) {
            ((try? FileManager.default.contentsOfDirectory(atPath: recovery.path)) ?? []).contains { $0.hasSuffix(".halo") }
        }
        XCTAssert(autosaved, "no copy autosaved under \(recovery.path)")
        halo.app.terminate()
        halo = Journey("Halo", self, arguments: size + store)
        let offer = "Restore the autosaved changes to \u{201C}title\u{201D}?"
        let prompt = halo.app.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", offer, offer)).firstMatch
        XCTAssert(prompt.waitForExistence(timeout: 30), "the relaunch didn't offer \(offer)")
        halo.shot("recovery-offer")
        halo.app.buttons["suite.recovery.restore"].firstMatch.click()
        XCTAssert(subtitle("Edited", halo).waitForExistence(timeout: 10), "the restored project isn't marked edited")
        expectKeys(through: 3, halo)
        halo.shot("recovery-restored")
    }

    /// Types `value` into the selected layer's Position X row (`halo.inspector.row.x`), as H-J23 types.
    @MainActor private func typeX(_ value: Int, _ halo: Journey) {
        let bar = halo.element("halo.inspector.row.x")
        XCTAssert(bar.waitForExistence(timeout: 5), "no Position X row (halo.inspector.row.x)")
        bar.click()
        // The row's own field: the inspector's first is FILL's Color Hex, off screen under a solid (#4559).
        let field = bar.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking Position X opened no field")
        halo.press(character: "a", .command)
        field.typeText("\(value)")
        halo.press(.return)
        XCTAssert(waitFor { !field.exists }, "Return didn't close Position X's field")
    }

    /// Ball's x keys sit at 0 through `last` and at 24, none at `last + 1`: the project after `last + 1` edits.
    @MainActor private func expectKeys(through last: Int, _ halo: Journey) {
        let key = { (frame: Int) in halo.element("halo.timeline.key.\(Self.ball).\(frame)") }
        XCTAssert(waitFor { !key(last + 1).exists }, "Ball still has a key at \(last + 1)")
        for frame in Array(0...last) + [24] {
            XCTAssert(key(frame).exists, "Ball has no key at \(frame)")
        }
    }

    /// Whether `condition` holds within `seconds`.
    @MainActor private func waitFor(seconds: Double, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }
}
