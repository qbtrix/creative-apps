// HaloJourneyTests+TextStyle.swift (text-style TS-10, HJ-TS): Halo's title
// card journey. On `-HaloSample empty` it adds Layer > New > Text, types
// Title, Option-Return (the field editor's line break) and Card in the TEXT
// field and presses Return, picks the first family in the font picker that
// isn't System UI and Bold from its Face menu, types 50 into Letter Spacing,
// clicks Align Center, then scrubs to frame 1 and presses ⌘R. Each style
// control records one step, read as the Edit menu's first item: "Undo Font",
// "Undo Letter Spacing", "Undo Alignment" (the kernel's text command titles).
// The rows are TextStyleRows (`suite.text.*`; the picker's own parts
// `suite.fontpicker.*`), run by HaloWindow+Text.swift's `haloText`; a bar's
// click opens its typing field, as H-J22's size bar. The artboard is read by
// `halo.viewer.summary`'s label and the render by `halo.viewer.rendered`. The
// Model half is HaloModelTests' HaloTextLayoutTests; the headless half is the
// real job RJ-H04 (Tests/RealJobs/halo/title-card). One shot per step,
// `halo-title-card-<n>-<step>`.
import XCTest

final class HaloTextStyleJourneyTests: XCTestCase {
    private static let stringID = "halo.inspector.text.string"

    /// HJ-TS: a two-line title card in a picked family, Bold, tracked and centred, rendered.
    @MainActor func testTitleCard() {
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "empty", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. A text layer with two lines: Title, a line break, Card.
        choose(["Layer", "New", "Text"], halo)
        let field = halo.element(Self.stringID)
        XCTAssert(field.waitForExistence(timeout: 10), "a new text layer shows no TEXT field (\(Self.stringID))")
        scrollInspector(toShow: field, halo)
        field.click()
        halo.press(character: "a", .command)
        field.typeText("Title")
        halo.press(.return, .option)
        field.typeText("Card")
        halo.press(.return)
        let summary = halo.element("halo.viewer.summary")
        XCTAssert(waitFor { summary.label.hasSuffix("Title\nCard") }, "the artboard reads \(summary.label), not two lines")
        expectUndo("Undo Edit Text", halo)
        halo.shot("title-card-1-two-lines")

        // 2. A family from the picker, then Bold from its Face menu.
        let picker = halo.element("suite.fontpicker")
        scrollInspector(toShow: picker, halo)
        let rows = picker.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@",
                        "suite.fontpicker.family.", "suite.fontpicker.family.System UI"))
        let row = rows.firstMatch
        XCTAssert(row.waitForExistence(timeout: 5), "the font picker lists no family but System UI")
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()  // #4790
        expectUndo("Undo Font", halo)
        let types = [XCUIElement.ElementType.menuButton, .popUpButton, .button].map { NSNumber(value: $0.rawValue) }
        let face = picker.descendants(matching: .any).matching(NSPredicate(
            format: "elementType IN %@ AND (identifier == %@ OR label == %@)", types, "suite.fontpicker.face", "Face")).firstMatch
        XCTAssert(face.waitForExistence(timeout: 5), "no Face menu (suite.fontpicker.face)")
        face.click()
        let bold = halo.app.menuItems["Bold"].firstMatch
        XCTAssert(bold.waitForExistence(timeout: 3), "the picked family's Face menu has no Bold")
        bold.click()
        expectUndo("Undo Font", halo)
        halo.shot("title-card-2-bold")

        // 3. Letter Spacing 50.
        type("50", into: "suite.text.tracking", halo)
        expectUndo("Undo Letter Spacing", halo)
        halo.shot("title-card-3-tracking")

        // 4. Align Center.
        let center = halo.element("suite.text.alignment.center")
        scrollInspector(toShow: center, halo)
        center.click()
        expectUndo("Undo Alignment", halo)
        halo.shot("title-card-4-centred")

        // 5. Scrub to frame 1 and render it: the render shows the styled card.
        let title = halo.trackName("Text 1")
        XCTAssert(title.waitForExistence(timeout: 10), "no Text 1 track title in the timeline")
        title.click()
        halo.press(.home)
        halo.press(.rightArrow)
        XCTAssert(waitFor { summary.label.hasPrefix("Frame 1:") }, "the artboard reads \(summary.label), not frame 1")
        halo.press(character: "r", .command)
        XCTAssert(halo.element("halo.viewer.rendered").waitForExistence(timeout: 10), "⌘R showed no rendered frame")
        expectUndo("Undo Alignment", halo)
        halo.shot("title-card-5-rendered")
    }

    // MARK: - Helpers

    /// Clicks the bar `id`, selects its typing field's text and types `value` and Return.
    @MainActor private func type(_ value: String, into id: String, _ halo: Journey) {
        let bar = halo.element(id)
        scrollInspector(toShow: bar, halo)
        let row = bar.frame
        bar.click()
        let fields = halo.element("suite.inspector").textFields
            .matching(NSPredicate(format: "identifier != %@", Self.stringID))
        XCTAssert(
            waitFor { fields.allElementsBoundByIndex.contains { $0.frame.midY >= row.minY && $0.frame.midY <= row.maxY } },
            "clicking \(id) opened no field")
        halo.press(character: "a", .command)
        halo.app.typeText(value)
        halo.press(.return)
    }

    /// Scrolls the inspector (`suite.inspector`) until `element` lies whole inside it.
    @MainActor private func scrollInspector(toShow element: XCUIElement, _ halo: Journey) {
        let inspector = halo.element("suite.inspector")
        XCTAssert(inspector.waitForExistence(timeout: 5), "no inspector (suite.inspector)")
        XCTAssert(element.waitForExistence(timeout: 5), "nothing to scroll to in the inspector")
        for _ in 0..<20 where !inspector.frame.contains(element.frame) {
            inspector.scroll(byDeltaX: 0, deltaY: element.frame.minY < inspector.frame.minY ? 40 : -40)
        }
        XCTAssert(inspector.frame.contains(element.frame), "scrolling didn't bring \(element.frame) into \(inspector.frame)")
    }

    /// Opens the menu bar item `path[0]`, hovers each submenu and returns the last item (the menu stays open).
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

    /// The Edit menu's first item reads `title`; the menu is closed again.
    @MainActor private func expectUndo(_ title: String, _ halo: Journey) {
        let edit = menuItem(["Edit"], halo)
        let first = edit.menus.firstMatch.children(matching: .menuItem).firstMatch
        XCTAssert(first.waitForExistence(timeout: 3), "the Edit menu shows no items")
        XCTAssertEqual(first.title, title, "the Edit menu's first item")
        halo.press(.escape)
        XCTAssert(halo.menusClosed(), "a menu stayed open after Escape")
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
