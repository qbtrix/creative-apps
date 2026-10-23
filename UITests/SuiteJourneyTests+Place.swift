// SuiteJourneyTests+Place.swift: the gallery's `place-image` page (Sources/SuiteUI/Gallery/GalleryPlaceImage.swift),
// Journey steps 1 to 6 of docs/blueprints/suiteui/features/placed-images.md (numbered below), in Library, shot under
// `suiteui`. The page's controls are `suite.place.*`: `choose` (Place…), `sample.png` and `sample.svg`, `canvas`
// (its value "<name>, W by H pixels"), `file` (the inspector's file row), `replace` and `reset-size`; it logs
// `<command id> <intent>` to `suite.gallery.log`. On since PL-4. The page holds one image and has no box or focus
// gesture yet, so steps 4 and 5 (the edge drag and ⌥-drag) are proven by `RenderBudgetPlaceTests` and the
// `suiteui-place-cover` snapshot until PL-8's live page; Replace… opens a file panel, which a journey can't drive.
import XCTest

final class SuitePlaceJourneyTests: XCTestCase {
    private static let placeWait = false
    private static let controls = ["choose", "sample.png", "sample.svg", "replace", "reset-size"].map { "suite.place.\($0)" }

    @MainActor func testPlaceImageOnGallery() throws {
        if Self.placeWait { throw XCTSkip("waits on PL-4") }
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index", "-SuitePerfProbe"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.element("suite.gallery.index.place-image").click() // 1. An empty canvas, Place… and two samples.
        let canvas = gallery.element("suite.place.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "no suite.place.canvas")
        XCTAssertEqual(canvas.label, "Empty canvas", "the empty canvas's VoiceOver label")
        for control in ["choose", "sample.png", "sample.svg"] where !gallery.element("suite.place.\(control)").exists {
            XCTFail("no suite.place.\(control)")
        }
        XCTAssert(gallery.element("suite.place.choose").isEnabled, "Place… is disabled")
        XCTAssertFalse(gallery.element("suite.place.file").exists, "the file row shows with nothing placed")
        gallery.shot("place-empty")

        gallery.element("suite.place.sample.png").click() // 2. Wide PNG fits to 800 × 267, centred.
        expectPlaceLog(gallery, "place.image", "Wide PNG logged no place.image")
        XCTAssertEqual(canvas.value as? String, "wide.png, 1200 by 400 pixels")
        XCTAssertEqual(gallery.element("suite.place.file").value as? String, "wide.png · PNG · 1200 × 400 px")
        gallery.shot("place-wide")

        gallery.element("suite.place.sample.svg").click() // 3. Logo SVG at its natural 240 × 80.
        expectPlaceLog(gallery, "place.image", "Logo SVG logged no place.image")
        XCTAssertEqual(canvas.value as? String, "logo.svg, 240 by 80")
        XCTAssertEqual(gallery.element("suite.place.file").value as? String, "logo.svg · SVG · 240 × 80")
        gallery.shot("place-svg")

        // 4 and 5 need the page's box and focus gestures (PL-8); the wide image comes back for 6.
        gallery.element("suite.place.sample.png").click()
        XCTAssert(wait(5) { canvas.value as? String == "wide.png, 1200 by 400 pixels" }, "Wide PNG didn't come back")

        // 6. Reset Size keeps the box at 3:1; every control is live; VoiceOver reads the image.
        let reset = gallery.element("suite.place.reset-size")
        XCTAssert(reset.waitForExistence(timeout: 5), "no suite.place.reset-size")
        XCTAssert(gallery.element("suite.place.replace").isEnabled, "Replace… is disabled")
        reset.click()
        expectPlaceLog(gallery, "place.reset-size", "Reset Size logged no place.reset-size")
        XCTAssertEqual(canvas.label, "Image", "the placed canvas's VoiceOver label")
        XCTAssertEqual(canvas.value as? String, "wide.png, 1200 by 400 pixels", "the image after Reset Size")
        let entries = gallery.controls()?.controls ?? []
        for id in Self.controls {
            let entry = entries.first { $0.id == id }
            XCTAssertEqual(entry?.enabled, true, "\(id) isn't an enabled control in suite.controls: \(entry.map { "\($0)" } ?? "missing")")
        }
        gallery.shot("place-reset")
    }

    /// Waits up to five seconds for a line of the page's log to start with `id`.
    @MainActor private func expectPlaceLog(_ gallery: Journey, _ id: String, _ message: String) {
        let log = gallery.element("suite.gallery.log")
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@ OR label CONTAINS %@", id, "\n\(id)"), object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(message); the log reads \(log.value ?? "nothing")")
    }

    /// Polls `condition` every tenth of a second for up to `seconds`.
    @MainActor private func wait(_ seconds: Double, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
