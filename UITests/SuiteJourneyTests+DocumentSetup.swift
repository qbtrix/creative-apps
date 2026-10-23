// SuiteJourneyTests+DocumentSetup.swift: SJ-DS, the gallery's `new-document` page (document-setup DS-6, the
// packet's Journey steps; docs/blueprints/suiteui/features/document-setup.md): open the page, pick a preset, switch
// to inches, type 4 by 6 at 300, pick Transparent and swap the orientation; the pixel readout says 1800 × 1200 and
// Create logs `file.new`.
import XCTest

final class SuiteDocumentSetupJourneyTests: XCTestCase {
    @MainActor func testNewSheetPresetsAndUnits() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.element("suite.gallery.index.new-document").click() // 1. Open the New Document page.
        XCTAssert(gallery.element("suite.newdoc").waitForExistence(timeout: 10), "no New Document sheet (suite.newdoc)")
        gallery.shot("new-document-open")

        gallery.element("suite.newdoc.preset").click() // 2. Pick a preset.
        gallery.app.menuItems["Vertical 9:16"].firstMatch.click()
        XCTAssertEqual(gallery.element("suite.newdoc.pixels").value as? String, "1080 × 1920 px")

        gallery.element("suite.newdoc.unit").click() // 3. Switch to inches.
        gallery.app.menuItems["in"].firstMatch.click()
        for (id, text) in [("width", "4"), ("height", "6"), ("resolution", "300")] { // 4. Type 4 by 6 at 300.
            let field = gallery.element("suite.newdoc.\(id)")
            field.doubleClick()
            gallery.press(character: "a", .command)
            gallery.app.typeText(text)
        }
        XCTAssertEqual(gallery.element("suite.newdoc.pixels").value as? String, "1200 × 1800 px")
        gallery.shot("new-document-inches")

        gallery.app.radioButtons["Transparent"].firstMatch.click() // 5. Transparent, then swap.
        gallery.element("suite.newdoc.swap").click()
        XCTAssertEqual(gallery.element("suite.newdoc.pixels").value as? String, "1800 × 1200 px")
        gallery.shot("new-document-swapped")

        gallery.press(.return) // Return creates.
        let log = gallery.element("suite.gallery.log").value as? String ?? ""
        XCTAssert(log.hasSuffix("file.new 6 × 4 in at 300 ppi"), "the log reads \(log)")
    }
}
