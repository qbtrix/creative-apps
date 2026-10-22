// PhotoJourneyTests+Text.swift: PJ-TX, a title over a photo (text-layers
// TX-2, turned on in TX-7; docs/blueprints/photo/features/text-layers.md,
// Journey steps; RJ-P02). On the shared test photo written as beach.png: T
// picks the Type tool, a click in the sky opens the box (`photo.text.box`),
// SUMMER SALE and Return add one text layer named after its words (the box's
// Escape drops the words, so Return commits). The inspector's Text section
// (`photo.text.*`) sets System UI Bold, size 120 and Center, one step each,
// and Undo walks them back one at a time. Save as Photo Document writes
// beach.ora; reopened from Open Recent the layer is still text, and a Type
// tool click on it edits SALE into DEALS. Until shell-text's live slot
// (ST-8) the window draws through PhotoServices' FakeText, whose system
// family is System UI with a Bold face. Shots `text-editing`,
// `text-inspector`, `text-done` and `text-reopened`.
import XCTest

final class PhotoTextJourneyTests: XCTestCase {
    /// PJ-TX:
    /// 1. T picks the Type tool; a click on the sky, SUMMER SALE and Return leave one text layer above the photo.
    /// 2. The inspector's style row: a heavy weight, size 120 and Center redraw it; Undo steps back one at a time.
    /// 3. Save, close, reopen: the layer is still text; a click on it with the Type tool changes SALE to DEALS.
    @MainActor func testTitleOverPhoto() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-text-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let beach = folder.appending(path: "beach.png")
        try writeTestPhoto(to: beach)
        var photo = Journey("Photo", self, arguments: photoArguments(open: beach, saveTo: folder))
        XCTAssert(photo.window(named: "beach.png").waitForExistence(timeout: 30), "beach.png didn't open")
        XCTAssert(photo.element("suite.canvas").waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        let photoOnly = steadyCanvas(photo)

        // 1. T, a click on the sky, SUMMER SALE, Return: one text layer, selected.
        typeTitle("SUMMER SALE", photo)
        expect("Undo Add Text", photo, "Return added no text layer")
        XCTAssert(photo.app.staticTexts["SUMMER SALE"].waitForExistence(timeout: 5), "no SUMMER SALE layer row")
        XCTAssert(Self.waitUntil { self.steadyCanvas(photo) != photoOnly }, "the text layer drew nothing")
        photo.shot("text-done")

        // 2. System UI Bold, 120, Center: one step each; Undo walks them back, Redo puts them again.
        XCTAssert(photo.element("photo.text.family").waitForExistence(timeout: 5), "no Text section (photo.text.family)")
        chooseFamily("System UI", photo)
        expect("Undo Font", photo, "the family made no Font step")
        chip("Bold", in: "photo.text.weight", photo)
        typeValue("120", into: "photo.text.size", photo)
        expect("Undo Text Size", photo, "120 made no Text Size step")
        chip("Center", in: "photo.text.alignment", photo)
        expect("Undo Alignment", photo, "Center made no Alignment step")
        let styled = steadyCanvas(photo)
        photo.shot("text-inspector")
        for title in ["Undo Text Size", "Undo Font", "Undo Font"] {
            photo.press(character: "z", .command)
            expect(title, photo, "one Command-Z didn't step back to \(title)")
        }
        for _ in 0..<3 { photo.press(character: "z", [.command, .shift]) }
        expect("Undo Alignment", photo, "Redo didn't put the three steps back")
        XCTAssert(Self.waitUntil { self.steadyCanvas(photo) == styled }, "Redo didn't redraw the styled title")

        // 3. Save as Photo Document, quit, Open Recent: still text; SALE becomes DEALS.
        photo.press(character: "s", .command)
        let keep = alert(photo)
        let document = keep.buttons["photo.file.keep-layers.document"].firstMatch
        XCTAssert(document.waitForExistence(timeout: 10), "Save asked no Keep layers?")
        document.click()
        XCTAssert(photo.window(named: "beach.ora").waitForExistence(timeout: 30), "the window isn't titled beach.ora")
        photo.press(character: "q", .command)
        if !photo.app.wait(for: .notRunning, timeout: 15) { photo.app.terminate() }
        photo = Journey("Photo", self, arguments: photoArguments(saveTo: folder))
        XCTAssert(photo.app.windows.firstMatch.waitForExistence(timeout: 30), "Photo didn't relaunch")
        openRecent("beach.ora", photo)
        XCTAssert(photo.window(named: "beach.ora").waitForExistence(timeout: 30), "Open Recent didn't reopen beach.ora")
        XCTAssert(photo.app.staticTexts["SUMMER SALE"].waitForExistence(timeout: 10), "the reopened file lost the text layer")
        photo.press(character: "t")
        photo.element("suite.canvas").coordinate(withNormalizedOffset: Self.title).click()
        let box = photo.element("photo.text.box")
        XCTAssert(box.waitForExistence(timeout: 5), "a Type tool click on the title opened no box")
        XCTAssertEqual(box.value as? String, "SUMMER SALE", "the reopened layer's words aren't text any more")
        photo.press(character: "a", .command)
        photo.app.typeText("SUMMER DEALS")
        photo.press(.return)
        expect("Undo Edit Text", photo, "Return made no Edit Text step")
        XCTAssert(photo.app.staticTexts["SUMMER DEALS"].waitForExistence(timeout: 5), "the layer row didn't follow the words")
        photo.shot("text-reopened")
    }

    /// Where the title goes: the sky, a fifth of the way down the canvas.
    private static let title = CGVector(dx: 0.3, dy: 0.2)

    /// T, a click on the sky, `words`, Return.
    @MainActor private func typeTitle(_ words: String, _ photo: Journey) {
        photo.press(character: "t")
        let tool = photo.element("suite.tools").buttons["Type"]
        XCTAssert(tool.waitForExistence(timeout: 5) && tool.isSelected, "T didn't pick the Type tool")
        photo.element("suite.canvas").coordinate(withNormalizedOffset: Self.title).click()
        XCTAssert(photo.element("photo.text.box").waitForExistence(timeout: 5), "the click opened no text box (photo.text.box)")
        photo.app.typeText(words)
        photo.shot("text-editing")
        photo.press(.return)
    }

    /// Picks `family` from the Text section's Family menu (`photo.text.family`).
    @MainActor private func chooseFamily(_ family: String, _ photo: Journey) {
        let types = [XCUIElement.ElementType.menuButton, .popUpButton, .button].map { NSNumber(value: $0.rawValue) }
        let picker = photo.element("suite.inspector").descendants(matching: .any).matching(NSPredicate(format:
            "elementType IN %@ AND (identifier == 'photo.text.family' OR label == 'Family')", types)).firstMatch
        XCTAssert(picker.waitForExistence(timeout: 5), "no Family menu (photo.text.family)")
        picker.click()
        let item = photo.app.menus.firstMatch.descendants(matching: .menuItem).matching(NSPredicate(format: "title == %@", family)).firstMatch
        XCTAssert(item.waitForExistence(timeout: 3), "the Family menu has no \(family)")
        item.click()
    }

    /// Clicks the chip titled `title` in the group identified by `group`.
    @MainActor private func chip(_ title: String, in group: String, _ photo: Journey) {
        let button = photo.element(group).buttons[title]
        XCTAssert(button.waitForExistence(timeout: 5) && button.isEnabled, "no enabled \(title) chip in \(group)")
        button.click()
    }

    /// Types `value` into the scrub field identified by `id`: click it, clear it, type, Return.
    @MainActor private func typeValue(_ value: String, into id: String, _ photo: Journey) {
        let panel = photo.element("suite.inspector")
        let target = panel.descendants(matching: .any)[id].firstMatch
        XCTAssert(target.waitForExistence(timeout: 5), "no \(id) in the inspector")
        target.click()
        let field = panel.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking \(id) opened no field")
        field.click()
        photo.app.typeKey(.rightArrow, modifierFlags: .command)
        for _ in 0..<16 { photo.app.typeKey(.delete, modifierFlags: []) }
        photo.app.typeText(value)
        photo.app.typeKey(.return, modifierFlags: [])
    }

    /// Waits for the button titled `title`, such as the window toolbar's "Undo Add Text".
    @MainActor private func expect(_ title: String, _ photo: Journey, _ message: String) {
        XCTAssert(photo.app.buttons[title].waitForExistence(timeout: 5), "\(message) (no \(title) button)")
    }

    /// A system alert: the window's sheet, or a dialog.
    @MainActor private func alert(_ photo: Journey) -> XCUIElement {
        let sheet = photo.app.sheets.firstMatch
        return sheet.waitForExistence(timeout: 10) ? sheet : photo.app.dialogs.firstMatch
    }

    /// File > Open Recent: `name` is the first entry; clicks it.
    @MainActor private func openRecent(_ name: String, _ photo: Journey) {
        let file = photo.app.menuBars.firstMatch.menuBarItems["File"]
        XCTAssert(file.waitForExistence(timeout: 5), "no File menu")
        file.click()
        let parent = file.menuItems["Open Recent"]
        XCTAssert(parent.waitForExistence(timeout: 3), "the File menu has no Open Recent")
        parent.hover()
        let first = parent.menus.firstMatch.children(matching: .menuItem).firstMatch
        XCTAssertEqual(first.title, name, "Open Recent's first entry")
        first.click()
    }

    /// The canvas a second after it was last asked to draw (it renders off the main actor).
    @MainActor private func steadyCanvas(_ photo: Journey) -> Data {
        Thread.sleep(forTimeInterval: 1)
        return photo.element("suite.canvas").screenshot().pngRepresentation
    }

    /// Waits up to 5 seconds for `condition` to hold.
    @MainActor private static func waitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<10 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }
}
