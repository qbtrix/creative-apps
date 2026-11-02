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

    /// The slice FJ-CB waits on; CB-8 set it to nil.
    private static let copyOutWaitsOn: String? = nil
    /// The slice the SVG paste (step 3) waits on: Flare's place path turns an SVG's groups into layers; nil once built.
    private static let svgPasteWaitsOn: String? = "svg-place PF-5"
    private static let svgType = NSPasteboard.PasteboardType("public.svg-image")
    /// Two groups, red and blue: svg-place makes a layer of each, named after the group.
    private static let logo = """
    <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 200 100">
    <g id="red"><rect x="10" y="10" width="80" height="80" fill="#E53935"/></g>
    <g id="blue"><rect x="110" y="10" width="80" height="80" fill="#1E88E5"/></g>
    </svg>
    """

    /// FJ-CB (clipboard-interop CB-7 writes it skipped, CB-8 turns it on): at frame 12, Ball, Edit > Copy writes
    /// Flare's layers, an SVG and a PNG (`edit-copy-types`); an SVG logo written to the pasteboard, then Edit > Paste:
    /// its red and blue groups appear in LAYERS as one "Paste" step (`edit-paste-svg`).
    @MainActor func testCopyOutPasteImageIn() throws {
        if let waitsOn = Self.copyOutWaitsOn { throw XCTSkip("waits on \(waitsOn)") }
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let sidebar = flare.element("suite.sidebar")
        XCTAssert(sidebar.staticTexts["Ball"].waitForExistence(timeout: 10), "LAYERS shows no Ball")

        // 1. The playhead on frame 12: Go to Start, then Next Frame twelve times.
        flare.element("flare.timeline.goToStart").click()
        let forward = flare.element("flare.timeline.step.forward")
        XCTAssert(forward.waitForExistence(timeout: 5), "no Next Frame button (flare.timeline.step.forward)")
        for _ in 0..<12 { forward.click() }
        let readout = flare.element("flare.timeline.frame")
        XCTAssert(waitFor { Int(readout.label.prefix { $0.isNumber }) == 12 }, "the playhead isn't on frame 12")

        // 2. Ball, Edit > Copy: own layers, SVG and PNG on the pasteboard.
        let pasteboard = NSPasteboard.general
        _ = pasteboard.clearContents()
        flare.pickSidebarRow("Ball")
        choose("Copy", flare)
        XCTAssert(waitFor { pasteboard.data(forType: .png) != nil }, "Copy put no PNG on the pasteboard")
        let types = pasteboard.types ?? []
        for type in [Self.layersType, Self.svgType, .png] {
            XCTAssert(types.contains(type), "Copy left \(type.rawValue) off the pasteboard (it holds \(types.map(\.rawValue)))")
        }
        flare.shot("edit-copy-types")

        // 3. An SVG logo on the pasteboard, Edit > Paste: its two groups are layers, one step.
        if let waitsOn = Self.svgPasteWaitsOn { throw XCTSkip("the SVG paste waits on \(waitsOn)") }
        _ = pasteboard.clearContents()
        XCTAssert(pasteboard.setData(Data(Self.logo.utf8), forType: Self.svgType), "could not put an SVG on the pasteboard")
        choose("Paste", flare)
        XCTAssert(sidebar.staticTexts["red"].waitForExistence(timeout: 5), "Paste of the SVG added no red layer")
        XCTAssert(sidebar.staticTexts["blue"].exists, "Paste of the SVG added no blue layer")
        expectUndo("Undo Paste", flare)
        flare.shot("edit-paste-svg")
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
