// FlareJourneyTests+Edit.swift: J15 (stage-edit SE-3) on `-FlareSample bounce` (Background locked, Shadow, Ball).
// Ball picked in LAYERS, Edit > Copy puts it on the system pasteboard under the suite's Flare layers type
// ("org.creativesuite.flare.layers"); Paste adds "Ball copy" and Duplicate "Ball copy 2", each one undo step;
// Cut takes Shadow away and Paste brings it back as "Shadow copy"; Delete removes "Ball copy 2". With the
// pasteboard cleared, Edit > Paste is disabled and its help tag shows (`edit-paste-disabled`). A right click
// on Ball on the stage opens the context menu: Cut, Copy, Duplicate, Delete, Bring Forward and Send Backward
// (`stage-context-menu`). A scene point is the artboard's top-left corner plus the point at its fit scale. Rows are
// picked off their names and read selected before the menu opens (Journey.pickSidebarRow, #2496, #2730).
import AppKit
import XCTest

final class FlareEditJourneys: XCTestCase {
    private static let sceneWidth = 550.0
    private static let layersType = NSPasteboard.PasteboardType("org.creativesuite.flare.layers")

    /// J15: copy, paste, duplicate, cut and delete layers through the Edit menu; Paste disabled when empty.
    @MainActor func testCopyPasteDuplicateDelete() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let sidebar = flare.element("suite.sidebar")
        XCTAssert(sidebar.staticTexts["Ball"].waitForExistence(timeout: 10), "LAYERS shows no Ball")

        // 1. Ball, Edit > Copy: the pasteboard holds Flare layers.
        _ = NSPasteboard.general.clearContents()
        flare.pickSidebarRow("Ball")
        choose("Copy", flare)
        XCTAssert(waitFor { NSPasteboard.general.data(forType: Self.layersType) != nil },
                  "Copy put no Flare layers on the pasteboard")
        flare.shot("edit-1-copied")

        // 2. Paste: "Ball copy", one step.
        choose("Paste", flare)
        XCTAssert(sidebar.staticTexts["Ball copy"].waitForExistence(timeout: 5), "Paste added no Ball copy")
        expectUndo("Undo Paste", flare)
        flare.shot("edit-2-pasted")

        // 3. Duplicate the pasted copy: "Ball copy 2".
        choose("Duplicate", flare)
        XCTAssert(sidebar.staticTexts["Ball copy 2"].waitForExistence(timeout: 5), "Duplicate added no Ball copy 2")
        expectUndo("Undo Duplicate", flare)
        flare.shot("edit-3-duplicated")

        // 4. Shadow, Cut: it goes; Paste brings it back renamed.
        flare.pickSidebarRow("Shadow")
        choose("Cut", flare)
        XCTAssert(sidebar.staticTexts["Shadow"].waitForNonExistence(timeout: 5), "Cut left Shadow in LAYERS")
        expectUndo("Undo Cut", flare)
        choose("Paste", flare)
        XCTAssert(sidebar.staticTexts["Shadow copy"].waitForExistence(timeout: 5), "Paste after Cut added no Shadow copy")
        flare.shot("edit-4-cut-pasted")

        // 5. "Ball copy 2", Delete: it goes.
        flare.pickSidebarRow("Ball copy 2")
        choose("Delete", flare)
        XCTAssert(sidebar.staticTexts["Ball copy 2"].waitForNonExistence(timeout: 5), "Delete left Ball copy 2")
        expectUndo("Undo Delete", flare)
        flare.shot("edit-5-deleted")

        // 6. An empty pasteboard: Paste is disabled and says why.
        _ = NSPasteboard.general.clearContents()
        expectDisabledWithHelp("Paste", flare)

        // 7. Right click Ball on the stage (at (80, 100) on frame 0): the stage's context menu.
        flare.pickSidebarRow("Ball")
        let canvas = flare.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "no stage (suite.canvas)")
        point(80, 100, on: canvas).rightClick()
        for item in ["Cut", "Copy", "Duplicate", "Delete", "Bring Forward", "Send Backward"] {
            XCTAssert(flare.app.menuItems[item].waitForExistence(timeout: 5), "the stage's context menu has no \(item)")
        }
        flare.shot("stage-context-menu", screen: true)
        flare.press(.escape)
    }

    /// Picks Edit > `item`, which must be enabled.
    @MainActor private func choose(_ item: String, _ flare: Journey) {
        let entry = editItem(item, flare)
        XCTAssert(entry.isEnabled, "Edit > \(item) is disabled")
        entry.click()
    }

    @MainActor private func editItem(_ item: String, _ flare: Journey) -> XCUIElement {
        let menu = flare.app.menuBars.firstMatch.menuBarItems["Edit"]
        XCTAssert(menu.waitForExistence(timeout: 5), "no Edit menu")
        menu.click()
        let entry = menu.menuItems[item]
        XCTAssert(entry.waitForExistence(timeout: 3), "the Edit menu has no \(item)")
        return entry
    }

    /// The Edit menu's Undo item reads `title`, the step just made.
    @MainActor private func expectUndo(_ title: String, _ flare: Journey) {
        let menu = flare.app.menuBars.firstMatch.menuBarItems["Edit"]
        menu.click()
        XCTAssert(menu.menuItems[title].waitForExistence(timeout: 3), "the Edit menu has no \(title)")
        flare.press(.escape)
    }

    /// Edit > `item` is disabled with a help tag; the menu re-reads the pasteboard within a second.
    @MainActor private func expectDisabledWithHelp(_ item: String, _ flare: Journey) {
        var entry = editItem(item, flare)
        for _ in 0..<5 where entry.isEnabled {
            flare.press(.escape)
            Thread.sleep(forTimeInterval: 0.5)
            entry = editItem(item, flare)
        }
        XCTAssertFalse(entry.isEnabled, "Edit > \(item) is enabled")
        entry.hover()
        XCTAssert(flare.app.helpTags.firstMatch.waitForExistence(timeout: 5), "Edit > \(item) shows no help tag")
        flare.shot("edit-\(flare.slug(item))-disabled", screen: true)
        flare.press(.escape)
    }

    @MainActor private func point(_ x: Double, _ y: Double, on canvas: XCUIElement) -> XCUICoordinate {
        let scale = canvas.frame.width / Self.sceneWidth
        return canvas.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x * scale, dy: y * scale))
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }
}
