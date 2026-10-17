// HaloJourneyTests+Text.swift: H-J22, edit a text layer (text-layers, TX-7;
// docs/blueprints/halo/features/text-layers.md, Journey steps). On
// `-HaloSample empty` (Comp 1 with no layers, on live services; the text
// rasterizer is CoreText's in both modes) it adds Layer > New > Text, types
// Hello in the TEXT field and presses Return, types 96 into the size bar and
// presses Return, then clears the field and presses Return, which is refused.
// The TEXT section is HaloTextInspector.swift: the field is
// `halo.inspector.text.string` (its value the words), the size bar
// `halo.inspector.text.size` (a slider whose value is its `sizeText`,
// "72 px", or its number; a click opens its typing field, as H-J6's Rotation
// bar), and a refusal's caption is `halo.refusal`, labelled with its message.
// The Edit menu's first item is read after each commit, since after the size
// change the top step is "Change Text Size" (the packet's "Undo name in
// H-J22" note); a refusal records no step. The artboard is read by the label
// of `halo.viewer.summary` (the Model's viewerSummary; values read empty,
// #262), not the `halo.viewer.artboard` the packet names: that id is only the
// viewer drag's refusal control. TEXT sits below TRANSFORM, under the
// inspector's fold at 640 pt, so the inspector is scrolled to each control
// before it is used. The Model half of every step is HaloModelTests'
// HaloTextLayerTests. One shot per step, `halo-text-<step>`.
import XCTest

final class HaloTextJourneyTests: XCTestCase {
    private static let stringID = "halo.inspector.text.string", sizeID = "halo.inspector.text.size"
    private static let summary = "Frame 0: Text 1: Hello"

    /// H-J22: set a text layer's words and size from TEXT, and see a blank commit refused.
    @MainActor func testTextLayer() {
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "empty", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. Layer > New > Text: TEXT shows "Text" in the field and 72 px on the size bar.
        choose(["Layer", "New", "Text"], halo)
        let field = halo.element(Self.stringID), size = halo.element(Self.sizeID)
        XCTAssert(field.waitForExistence(timeout: 10), "a new text layer shows no TEXT field (\(Self.stringID))")
        scrollInspector(toShow: size, halo)
        expectField(reads: "Text", halo)
        expectSize(reads: "72 px", 72, halo)
        expectUndo("Undo New Layer", halo)
        halo.shot("text-1-new-layer")

        // 2. Type Hello in the field and press Return: one Edit Text step.
        scrollInspector(toShow: field, halo)
        field.click()
        halo.press(character: "a", .command)
        field.typeText("Hello")
        halo.press(.return)
        expectField(reads: "Hello", halo)
        expectSummary(halo)
        expectUndo("Undo Edit Text", halo)
        halo.shot("text-2-edit-text")

        // 3. Type 96 into the size bar and press Return: 96 px, one Change Text Size step.
        scrollInspector(toShow: size, halo)
        let bar = size.frame
        size.click()
        let typing = sizeField(near: bar, halo)
        XCTAssert(typing.waitForExistence(timeout: 5), "clicking the size bar opened no field")
        halo.press(character: "a", .command)
        typing.typeText("96")
        halo.press(.return)
        expectSize(reads: "96 px", 96, halo)
        expectField(reads: "Hello", halo)
        expectSummary(halo)
        expectUndo("Undo Change Text Size", halo)
        halo.shot("text-3-size-96")

        // 4. Clear the field and press Return: refused with "Enter some text."
        // under the field, which reads Hello again; no step is added.
        scrollInspector(toShow: field, halo)
        field.click()
        halo.press(character: "a", .command)
        halo.press(.delete)
        halo.press(.return)
        let caption = halo.element("halo.refusal"), message = "Enter some text."
        XCTAssert(caption.waitForExistence(timeout: 5), "a blank commit showed no refusal (halo.refusal)")
        XCTAssert(
            waitFor { caption.label == message || (caption.value as? String) == message },
            "the refusal reads \(caption.label), not \(message)")
        XCTAssertGreaterThanOrEqual(caption.frame.minY, field.frame.maxY, "the refusal caption isn't under the field")
        expectField(reads: "Hello", halo)
        expectSize(reads: "96 px", 96, halo)
        expectSummary(halo)
        expectUndo("Undo Change Text Size", halo)
        scrollInspector(toShow: caption, halo)
        halo.shot("text-4-refused")
    }

    // MARK: - Helpers

    /// The TEXT field reads `words` within three seconds.
    @MainActor private func expectField(reads words: String, _ halo: Journey) {
        let field = halo.element(Self.stringID)
        XCTAssert(
            waitFor { (field.value as? String) == words },
            "the TEXT field reads \(String(describing: field.value)), not \(words)")
    }

    /// The size bar reads `text` ("96 px") within three seconds, or its
    /// number `px` when it reads a bare number (a slider's position).
    @MainActor private func expectSize(reads text: String, _ px: Double, _ halo: Journey) {
        let size = halo.element(Self.sizeID)
        XCTAssert(
            waitFor {
                if let number = size.value as? NSNumber { return number.doubleValue == px }
                return (size.value as? String) == text
            }, "the size bar reads \(String(describing: size.value)), not \(text)")
    }

    /// The artboard's `halo.viewer.summary` label reads "Frame 0: Text 1: Hello".
    @MainActor private func expectSummary(_ halo: Journey) {
        let artboard = halo.element("halo.viewer.summary")
        XCTAssert(
            waitFor { artboard.label == Self.summary },
            "the artboard reads \(artboard.label), not \(Self.summary)")
    }

    /// The size bar's typing field: the inspector's text field that isn't
    /// TEXT's words and lies on the bar's row (`bar`, its frame before the click).
    @MainActor private func sizeField(near bar: CGRect, _ halo: Journey) -> XCUIElement {
        let fields = halo.element("suite.inspector").textFields
            .matching(NSPredicate(format: "identifier != %@", Self.stringID))
        var found: XCUIElement?
        _ = waitFor {
            found = fields.allElementsBoundByIndex.first { $0.frame.midY >= bar.minY && $0.frame.midY <= bar.maxY }
            return found != nil
        }
        return found ?? fields.firstMatch
    }

    /// Scrolls the inspector until `element` lies whole inside it, down when
    /// it sits below and up when above. `suite.inspector` is the inspector's
    /// scroll view.
    @MainActor private func scrollInspector(toShow element: XCUIElement, _ halo: Journey) {
        let inspector = halo.element("suite.inspector")
        XCTAssert(inspector.waitForExistence(timeout: 5), "no inspector (suite.inspector)")
        XCTAssert(element.waitForExistence(timeout: 5), "nothing to scroll to in the inspector")
        for _ in 0..<20 where !inspector.frame.contains(element.frame) {
            inspector.scroll(byDeltaX: 0, deltaY: element.frame.minY < inspector.frame.minY ? 40 : -40)
        }
        XCTAssert(inspector.frame.contains(element.frame), "scrolling didn't bring \(element.frame) into \(inspector.frame)")
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
