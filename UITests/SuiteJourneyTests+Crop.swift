// SuiteJourneyTests+Crop.swift: SJ-OC, the gallery's `crop` page (orientation-crop OC-6): open it, pick 4:5, press X
// and the frame turns portrait, then type a Custom 7:3; the log names crop.swap and crop.set-aspect.
import XCTest

final class SuiteCropJourneyTests: XCTestCase {
    @MainActor func testAspectSwapInGallery() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.element("suite.gallery.index.crop").click() // 1. Open the crop page.
        XCTAssert(gallery.element("suite.crop").waitForExistence(timeout: 10), "no crop picker (suite.crop)")
        XCTAssertFalse(gallery.element("suite.crop.orientation").isEnabled, "the toggle acts on Free")
        gallery.shot("crop-open")

        gallery.element("suite.crop.aspect-4-5").click() // 2. Pick 4:5.
        XCTAssert(gallery.element("suite.crop.orientation").isEnabled, "the toggle is off on 4:5")
        XCTAssertEqual(gallery.element("suite.gallery.crop.frame").label, "Crop frame landscape")
        gallery.shot("crop-four-five")

        gallery.press(character: "x") // 3. X turns the frame portrait.
        XCTAssertEqual(gallery.element("suite.gallery.crop.frame").label, "Crop frame portrait")
        gallery.shot("crop-portrait")

        gallery.element("suite.crop.aspect-custom").click() // 4. Type a Custom 7:3.
        for (id, text) in [("width", "7"), ("height", "3")] { gallery.element("suite.crop.custom-\(id)").click(); gallery.app.typeText(text) }
        XCTAssertEqual(gallery.element("suite.gallery.crop.frame").label, "Crop frame landscape")
        gallery.shot("crop-custom")
        let log = gallery.element("suite.gallery.log").value as? String ?? ""
        XCTAssert(log.contains("crop.swap 4:5 portrait"), "X sent no crop.swap: \(log)")
        XCTAssert(log.hasSuffix("crop.set-aspect 7:3 landscape"), "the log reads \(log)")
    }
}
