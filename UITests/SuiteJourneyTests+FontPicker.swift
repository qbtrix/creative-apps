// SuiteJourneyTests+FontPicker.swift: the gallery's `font-picker` page
// (packet docs/blueprints/suiteui/features/font-picker.md, Journey steps 1 to 5;
// written by FP-1, turned on by FP-4). The page runs on FakeText's three
// families (Mono, Serif, System UI). From the index it opens the page, types a
// query that narrows the list to System UI, picks its Bold face and sets the
// size to 36 (the log reads `pick(System UI, Bold, 36)`), then picks Serif,
// which has no Bold: the nearest face is Regular. Every row reads its family
// name, and the menu and the size row take the keyboard.
import XCTest

extension SuiteJourneyTests {
    /// FP-4: search, face, size and a family switch on the font picker's gallery page.
    @MainActor func testFontPickerPicksAFace() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")

        // 1. Open the page: FakeText's three families, the first selected.
        gallery.element("suite.gallery.index.font-picker").click()
        XCTAssert(gallery.element("suite.gallery.font-picker").waitForExistence(timeout: 10), "no root suite.gallery.font-picker")
        for name in ["Mono", "Serif", "System UI"] {
            XCTAssert(gallery.element("suite.fontpicker.family.\(name)").waitForExistence(timeout: 5), "no row for \(name)")
        }
        XCTAssert(gallery.element("suite.fontpicker.family.Mono").isSelected, "the first family isn't selected")
        gallery.shot("font-picker-open")

        // 2. Type a query: the list narrows to the family it starts.
        gallery.element("suite.fontpicker.search").click()
        gallery.app.typeText("sys")
        XCTAssert(gallery.element("suite.fontpicker.family.System UI").waitForExistence(timeout: 5), "System UI left the list")
        XCTAssertFalse(gallery.element("suite.fontpicker.family.Serif").exists, "Serif stayed in the list for \"sys\"")
        gallery.shot("font-picker-search")

        // 3. Pick System UI's Bold face, then set the size to 36: the log names the pick.
        clickFontPickerRow(gallery, "System UI")
        fontPickerFaceMenu(gallery).click()
        gallery.app.menuItems["Bold"].firstMatch.click()
        gallery.element("suite.fontpicker.size").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
        gallery.app.typeKey("a", modifierFlags: .command)
        gallery.app.typeText("36\r")
        expectFontPickerLog(gallery, "pick(System UI, Bold, 36)")
        gallery.shot("font-picker-faces")

        // 4. Clear the query and pick Serif: it has no Bold, so the nearest face is Regular.
        gallery.element("suite.fontpicker.search").click()
        gallery.app.typeKey("a", modifierFlags: .command)
        gallery.app.typeKey(.delete, modifierFlags: [])
        clickFontPickerRow(gallery, "Serif")
        expectFontPickerLog(gallery, "pick(Serif, Regular, 36)")

        // 5. Rows read their family name; Escape closes the open Face menu, and the arrow keys move the
        //    list's selection: Down from Serif picks System UI (Regular, its face nearest Serif's), Up goes back.
        XCTAssertEqual(gallery.element("suite.fontpicker.family.Mono").label, "Mono", "the Mono row doesn't read its name")
        fontPickerFaceMenu(gallery).click()
        XCTAssert(gallery.app.menus.firstMatch.waitForExistence(timeout: 3), "clicking Face opened no menu")
        gallery.app.typeKey(.escape, modifierFlags: [])
        XCTAssert(fontPickerWait { !gallery.app.menus.firstMatch.exists }, "Escape didn't close the Face menu")
        clickFontPickerRow(gallery, "Serif")
        gallery.press(.downArrow, step: "font-picker-keyboard")
        expectFontPickerLog(gallery, "pick(System UI, Regular, 36)")
        XCTAssert(fontPickerWait { gallery.element("suite.fontpicker.family.System UI").isSelected },
                  "Down didn't move the selection to System UI")
        gallery.shot("font-picker-keyboard")
        gallery.press(.upArrow, step: "font-picker-keyboard-up")
        expectFontPickerLog(gallery, "pick(Serif, Regular, 36)")
    }

    /// Clicks a family row at its centre: the List's ScrollView has no hit point
    /// for the row's text element on the macOS runner (#4790), so the click goes
    /// to the row's coordinate rather than through XCUIElement.click().
    @MainActor private func clickFontPickerRow(_ gallery: Journey, _ name: String) {
        let row = gallery.element("suite.fontpicker.family.\(name)")
        XCTAssert(row.waitForExistence(timeout: 5), "no row for \(name)")
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    /// The Face row's menu control; the row's identifier can also land on its group, so match the control types.
    @MainActor private func fontPickerFaceMenu(_ gallery: Journey) -> XCUIElement {
        let types = [XCUIElement.ElementType.menuButton, .popUpButton, .button].map { NSNumber(value: $0.rawValue) }
        let menu = gallery.element("suite.fontpicker").descendants(matching: .any).matching(
            NSPredicate(format: "elementType IN %@ AND (identifier == %@ OR label == %@)", types, "suite.fontpicker.face", "Face")
        ).firstMatch
        XCTAssert(menu.waitForExistence(timeout: 5), "no Face menu (suite.fontpicker.face)")
        return menu
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func fontPickerWait(_ condition: () -> Bool) -> Bool {
        for _ in 0..<10 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return condition()
    }

    @MainActor private func expectFontPickerLog(_ gallery: Journey, _ line: String) {
        let log = gallery.element("suite.gallery.log")
        let done = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", line), object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: 5), .completed, "the log reads \(log.value ?? "nothing"), not \(line)")
    }
}
