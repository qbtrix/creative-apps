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
    /// Off until FP-4 lands the view these steps drive (FP-3) and its identifiers.
    private static let fontPickerViewLanded = false

    /// FP-4: search, face, size and a family switch on the font picker's gallery page.
    @MainActor func testFontPickerPicksAFace() throws {
        guard Self.fontPickerViewLanded else { throw XCTSkip("waits on FP-4") }
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
        gallery.element("suite.fontpicker.family.System UI").click()
        gallery.element("suite.fontpicker.face").click()
        gallery.app.menuItems["Bold"].firstMatch.click()
        gallery.element("suite.fontpicker.size").doubleClick()
        gallery.app.typeKey("a", modifierFlags: .command)
        gallery.app.typeText("36\r")
        expectFontPickerLog(gallery, "pick(System UI, Bold, 36)")
        gallery.shot("font-picker-faces")

        // 4. Clear the query and pick Serif: it has no Bold, so the nearest face is Regular.
        gallery.element("suite.fontpicker.search").click()
        gallery.app.typeKey("a", modifierFlags: .command)
        gallery.app.typeKey(.delete, modifierFlags: [])
        gallery.element("suite.fontpicker.family.Serif").click()
        expectFontPickerLog(gallery, "pick(Serif, Regular, 36)")

        // 5. Rows read their family name; the face menu opens from the keyboard.
        XCTAssertEqual(gallery.element("suite.fontpicker.family.Mono").label, "Mono", "the Mono row doesn't read its name")
        gallery.element("suite.fontpicker.face").click()
        gallery.app.typeKey(.escape, modifierFlags: [])
        gallery.press(.downArrow, step: "font-picker-keyboard")
        gallery.shot("font-picker-keyboard")
    }

    @MainActor private func expectFontPickerLog(_ gallery: Journey, _ line: String) {
        let log = gallery.element("suite.gallery.log")
        let done = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", line), object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: 5), .completed, "the log reads \(log.value ?? "nothing"), not \(line)")
    }
}
