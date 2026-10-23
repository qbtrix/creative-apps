// SuiteJourneyTests+Lists.swift: steps 1 to 3 of docs/blueprints/suiteui/features/lists-and-layers.md (LL-14) on the
// gallery's `window` and `grid` pages (Sources/SuiteUI/Gallery/GalleryLists.swift), in Library, shot under `suiteui`.
// SJ1b opens `window` at four widths and checks the three columns against the window and their tokens; a width past
// the display (1280 and 1440 on the 1024 pt runner) is fitted to its visible frame by SuiteWindowSizer, so the window
// is held to the smaller of the two. Every shot is audited against `suiteui`'s baseline, whose `offscreen`, `overlap`
// and `contrast` are 0, so a count over 0 fails at its shot. SJ17 drives the window page's Layers rows by their
// toggles' identifiers (`suite.sidebar.<id>.<toggle>`), the rename field (`suite.sidebar.<id>.rename`) and the
// refusal under it (`.renameMessage`), and reads `suite.gallery.log`. SJ18 clicks `suite.grid.<id>` cells.
// Numbers are SuiteUI tokens (this bundle doesn't link SuiteUI).
import AppKit
import XCTest

final class SuiteListJourneys: XCTestCase {
    static let widths = [880.0, 1024, 1280, 1440]
    static let sidebarRange = 160.0...320.0  // SuiteSize.sidebarWidth min...max
    static let inspectorRange = 200.0...360.0  // SuiteSize.inspectorWidth min...max
    static let contentMinimum = 440.0  // SuiteSize.contentMinimum.width
    static let taken = "Another layer is already named Taken."  // GalleryLists.taken

    /// SJ1b (QB-S17): at each width the sidebar, content and inspector sit inside the window, no two overlap by more
    /// than 1 pt, the content is at least its minimum, and the side columns are within their token ranges.
    @MainActor func testWindowShellFitsAtEveryWidth() {
        for width in Self.widths {
            let size = "\(Int(width))x768"
            let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "window", "-SuiteWindowSize", size])
            XCTAssert(gallery.element("suite.gallery.window").waitForExistence(timeout: 30), "no window page at \(size)")
            XCTAssert(gallery.element("suite.sidebar").waitForExistence(timeout: 10), "no sidebar at \(size)")
            XCTAssert(gallery.element("suite.inspector").waitForExistence(timeout: 10), "no inspector at \(size)")
            let visible = Double(NSScreen.main?.visibleFrame.width ?? CGFloat(width))
            let expected = min(width, visible)
            let window = gallery.app.windows.firstMatch
            XCTAssert(waitFor { abs(Double(window.frame.width) - expected) <= 1 }, "the window is \(window.frame.width) pt wide, not \(expected) (\(size))")
            expectColumns(gallery, size: size)
            gallery.shot("lists-window-\(Int(width))")
            gallery.app.terminate()
        }
    }

    /// SJ17 (QB-F4): eye, lock, rename by double-click and by Return (refused for "Taken", Escape restores), drag
    /// reorder, a child row's own eye, and the rename guard: a double-click on a toggle or the blank space opens no field.
    @MainActor func testLayerListToggleRenameReorder() {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "window"])
        XCTAssert(gallery.element("suite.gallery.window").waitForExistence(timeout: 30), "no window page")
        let log = gallery.element("suite.gallery.log")
        XCTAssert(log.waitForExistence(timeout: 10), "no suite.gallery.log on the window page")
        let sidebar = gallery.element("suite.sidebar")

        // 1. Ball's eye, then Shadow's lock (its row dims; the toggle now offers to unlock).
        gallery.element("suite.sidebar.ball.eye").listMiddle.click()
        expectLog("toggle eye ball", log)
        let lock = gallery.element("suite.sidebar.shadow.lock")
        lock.listMiddle.click()
        expectLog("toggle lock shadow locked", log)
        XCTAssert(waitFor { lock.label == "Unlock Shadow" }, "Shadow's lock reads \(lock.label), not Unlock Shadow")
        gallery.shot("lists-layers-toggled")

        // 2. Double-click Ball's title, Hero, Return.
        let ballName = row("ball", gallery).staticTexts["Ball"].firstMatch
        XCTAssert(ballName.waitForExistence(timeout: 5), "no Ball title in its row")
        ballName.listMiddle.doubleClick()
        let ballField = gallery.element("suite.sidebar.ball.rename")
        XCTAssert(ballField.waitForExistence(timeout: 5), "double-clicking Ball's title opened no rename field")
        gallery.press(character: "a", .command)
        gallery.app.typeText("Hero")
        gallery.press(.return)
        expectLog("rename ball Hero", log)
        XCTAssert(ballField.waitForNonExistence(timeout: 5), "the rename field stayed open after Hero")

        // 3. Focus Shadow, Return, Taken, Return: refused with the page's message, the draft kept; Escape restores.
        pick("shadow", gallery)
        gallery.press(.return)
        let shadowField = gallery.element("suite.sidebar.shadow.rename")
        XCTAssert(shadowField.waitForExistence(timeout: 5), "Return on Shadow opened no rename field")
        gallery.press(character: "a", .command)
        gallery.app.typeText("Taken")
        gallery.press(.return)
        let message = gallery.element("suite.sidebar.shadow.renameMessage")
        XCTAssert(message.waitForExistence(timeout: 5), "Taken wasn't refused under the row")
        XCTAssertEqual(message.label, Self.taken, "the refusal under Shadow")
        XCTAssertEqual(shadowField.value as? String, "Taken", "the refused draft didn't stay")
        XCTAssertFalse(lines(log).contains { $0.hasPrefix("rename shadow") }, "the page renamed Shadow to Taken")
        gallery.shot("lists-layers-refused")
        gallery.press(.escape)
        XCTAssert(shadowField.waitForNonExistence(timeout: 5), "Escape left the rename field open")
        XCTAssert(row("shadow", gallery).staticTexts["Shadow"].firstMatch.waitForExistence(timeout: 5), "Escape didn't restore Shadow")

        // 4. Drag Shadow above Hero.
        let top = row("hero", gallery)
        row("shadow", gallery).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: top.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
        expectLog("move shadow 0", log)
        gallery.shot("lists-layers-reordered")

        // 5. Open Group; its own eye and lock and its child's eye are each one element (#589, #111, LL-9).
        let group = row("group", gallery)
        let disclosure = group.disclosureTriangles.firstMatch
        XCTAssert(disclosure.waitForExistence(timeout: 5), "Group's row has no disclosure")
        disclosure.listMiddle.click()
        expectLog("open group", log)
        for id in ["suite.sidebar.group.eye", "suite.sidebar.group.lock"] {
            let count = gallery.app.descendants(matching: .any).matching(identifier: id).count
            XCTAssertEqual(count, 1, "\(id) is \(count) elements in the open group, not its own one")
        }
        let childEye = gallery.element("suite.sidebar.child.eye")
        XCTAssert(childEye.waitForExistence(timeout: 5), "Child's eye isn't its own element")
        childEye.listMiddle.click()
        expectLog("toggle eye child", log)
        gallery.element("suite.sidebar.group.lock").listMiddle.click()
        expectLog("toggle lock group locked", log)
        gallery.shot("lists-layers-child")

        // 6. The rename guard (#308, #311, #312): a double-click on Ball's eye flips it twice and opens no field.
        let eye = gallery.element("suite.sidebar.ball.eye")
        let before = (label: eye.label, count: lines(log).filter { $0 == "toggle eye ball" }.count)
        eye.listMiddle.doubleClick()
        XCTAssert(waitFor { lines(log).filter { $0 == "toggle eye ball" }.count == before.count + 2 }, "a double-click on the eye didn't flip it twice")
        XCTAssertEqual(eye.label, before.label, "the eye didn't end where it started")
        expectNoField(sidebar, after: "a double-click on Ball's eye")

        // ...and one on the blank space between Ball's title and its toggles opens none either.
        let ball = row("ball", gallery)
        let name = ball.staticTexts["Hero"].firstMatch, first = gallery.element("suite.sidebar.ball.eye")
        XCTAssert(name.exists && name.frame.maxX < first.frame.minX, "no blank space between Ball's title and its toggles")
        let blank = (name.frame.maxX + first.frame.minX) / 2 - ball.frame.minX
        ball.coordinate(withNormalizedOffset: CGVector(dx: Double(blank / max(ball.frame.width, 1)), dy: 0.5)).doubleClick()
        expectNoField(sidebar, after: "a double-click on Ball's blank space")
        gallery.shot("lists-layers-guard")
    }

    /// SJ18 (QB-F4): click 3, Shift-click 6, Command-click 4, then Right: GridSelection's results, logged.
    @MainActor func testThumbnailGridSelectsByClickAndKeys() {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "grid"])
        XCTAssert(gallery.element("suite.gallery.grid").waitForExistence(timeout: 30), "no grid page")
        let log = gallery.element("suite.gallery.log")
        XCTAssert(log.waitForExistence(timeout: 10), "no suite.gallery.log on the grid page")
        let cell = { (id: Int) in gallery.element("suite.grid.\(id)") }
        XCTAssert(cell(3).waitForExistence(timeout: 10), "no grid cell suite.grid.3")

        cell(3).listMiddle.click()
        expectLog("3", log)
        XCUIElement.perform(withKeyModifiers: .shift) { cell(6).listMiddle.click() }
        expectLog("3,4,5,6", log)
        XCUIElement.perform(withKeyModifiers: .command) { cell(4).listMiddle.click() }
        expectLog("3,5,6", log)
        gallery.shot("lists-grid-picked")
        // 4 left the selection, so the anchor is the first selected cell, 3; Right lands on 4 alone.
        gallery.press(.rightArrow)
        expectLog("4", log)
        gallery.shot("lists-grid-moved")
    }

    // MARK: - Helpers

    /// SJ1b's column rules on the window as it is now.
    @MainActor private func expectColumns(_ gallery: Journey, size: String) {
        let window = gallery.app.windows.firstMatch
        guard let tree = try? window.snapshot() else { return XCTFail("no window snapshot at \(size)") }
        let columns = [
            "sidebar": Journey.columnFrame("suite.sidebar", in: tree),
            "content": Journey.columnFrame("suite.gallery.log", in: tree),
            "inspector": Journey.columnFrame("suite.inspector", in: tree),
        ]
        var regions: [String: AppAudit.Rect] = [:]
        for (name, frame) in columns {
            guard let frame else {
                XCTFail("no \(name) column at \(size)")
                continue
            }
            regions[name] = rect(frame)
        }
        let found = ShellGeometry.violations(
            window: rect(window.frame), regions: regions, minimums: ["content": (Self.contentMinimum - 1, 1)],
            apart: [("sidebar", "content"), ("sidebar", "inspector"), ("content", "inspector")], clear: [])
        XCTAssert(found.isEmpty, "the window page at \(size):\n" + found.joined(separator: "\n"))
        for (name, range) in [("sidebar", Self.sidebarRange), ("inspector", Self.inspectorRange)] {
            let width = regions[name]?.width ?? 0
            XCTAssert(width >= range.lowerBound - 1 && width <= range.upperBound + 1, "the \(name) is \(width) pt at \(size), outside \(range)")
        }
    }

    /// The outline row of the item `id`, found by its eye toggle's identifier.
    @MainActor private func row(_ id: String, _ gallery: Journey) -> XCUIElement {
        let row = gallery.element("suite.sidebar").outlineRows
            .containing(NSPredicate(format: "identifier == %@", "suite.sidebar.\(id).eye")).firstMatch
        XCTAssert(row.waitForExistence(timeout: 5), "the sidebar has no \(id) row")
        return row
    }

    /// Clicks the row `id` midway between its title and its first toggle, off the title's rename double-click.
    @MainActor private func pick(_ id: String, _ gallery: Journey) {
        let row = row(id, gallery)
        let name = row.staticTexts.firstMatch, eye = gallery.element("suite.sidebar.\(id).eye")
        var dx = 0.6
        if row.frame.width > 0, name.exists, name.frame.maxX < eye.frame.minX {
            dx = Double((name.frame.maxX + eye.frame.minX) / 2 - row.frame.minX) / Double(row.frame.width)
        }
        row.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.5)).click()
        XCTAssert(waitFor { row.isSelected }, "clicking the \(id) row didn't select it")
    }

    /// No text field opens in the sidebar within a second.
    @MainActor private func expectNoField(_ sidebar: XCUIElement, after step: String) {
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(sidebar.textFields.count, 0, "\(step) opened a rename field")
    }

    /// The log's lines, oldest first.
    @MainActor private func lines(_ log: XCUIElement) -> [String] {
        ((log.value as? String) ?? "").components(separatedBy: "\n")
    }

    /// The log's last line reads `line` within three seconds.
    @MainActor private func expectLog(_ line: String, _ log: XCUIElement) {
        XCTAssert(waitFor { lines(log).last == line }, "the log ends \(lines(log).last ?? "empty"), not \(line)")
    }

    private func rect(_ frame: CGRect) -> AppAudit.Rect {
        AppAudit.Rect(x: Double(frame.minX), y: Double(frame.minY), width: Double(frame.width), height: Double(frame.height))
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
