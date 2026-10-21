// SuiteJourneyTests+Place.swift: the gallery's `place-image` page (Sources/SuiteUI/Gallery/GalleryPlaceImage.swift),
// Journey steps 1 to 6 of docs/blueprints/suiteui/features/placed-images.md (numbered below), in Library, shot under
// `suiteui`. The page's controls are `suite.place.*`: `choose` (Place…), `sample.png` and `sample.svg`, `canvas`
// (its value "<name>, W by H pixels") and `file` (the inspector's file row); it logs `<command id> <intent>` to
// `suite.gallery.log`. It skips until PL-4 turns it on.
import XCTest

final class SuitePlaceJourneyTests: XCTestCase {
    private static let placeWait = true

    @MainActor func testPlaceImageOnGallery() throws {
        if Self.placeWait { throw XCTSkip("waits on PL-4") }
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.element("suite.gallery.index.place-image").click() // 1. An empty canvas, Place… and two samples.
        let canvas = gallery.element("suite.place.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "no suite.place.canvas")
        for control in ["choose", "sample.png", "sample.svg"] where !gallery.element("suite.place.\(control)").exists {
            XCTFail("no suite.place.\(control)")
        }
        gallery.shot("place-empty")

        gallery.element("suite.place.sample.png").click() // 2. Wide PNG fits to 800 × 267, centred.
        expectPlaceLog(gallery, "place.image", "Wide PNG logged no place.image")
        XCTAssertEqual(canvas.value as? String, "wide.png, 1200 by 400 pixels") // 6. VoiceOver.
        XCTAssertEqual(gallery.element("suite.place.file").value as? String, "wide.png · PNG · 1200 × 400 px")
        gallery.shot("place-wide")

        gallery.element("suite.place.sample.svg").click() // 3. Logo SVG at its natural 240 × 80.
        expectPlaceLog(gallery, "place.image", "Logo SVG logged no place.image")
        XCTAssertEqual(canvas.value as? String, "logo.svg, 240 by 80")
        gallery.shot("place-svg")
    }

    /// Waits up to five seconds for a line of the page's log to start with `id`.
    @MainActor private func expectPlaceLog(_ gallery: Journey, _ id: String, _ message: String) {
        let log = gallery.element("suite.gallery.log")
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@ OR label CONTAINS %@", id, "\n\(id)"), object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(message); the log reads \(log.value ?? "nothing")")
    }
}
