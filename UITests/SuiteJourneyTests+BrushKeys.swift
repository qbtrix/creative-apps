// SuiteJourneyTests+BrushKeys.swift (brush-keys BK-6, SJ-BK): `]` three times reads 35 px, 4 5 reads 45%, and a 9
// typed in the size field changes only the field.
import XCTest

final class SuiteBrushKeysJourneyTests: XCTestCase {
    @MainActor func testKeysStepSizeAndOpacity() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.element("suite.gallery.index.brush-keys").click() // 1. Open the Brush Keys page.
        XCTAssert(gallery.element("suite.gallery.brush-keys").waitForExistence(timeout: 10), "no suite.gallery.brush-keys")
        let canvas = gallery.element("suite.gallery.brush-canvas")
        XCTAssert(canvas.exists, "no suite.gallery.brush-canvas")
        expectStatus(gallery, "Size 20 px, opacity 100%")
        canvas.click()

        for _ in 0..<3 { gallery.press(character: "]") } // 2. `]` three times: 20 → 25 → 30 → 35.
        expectReadout(gallery, "Size 35 px")
        expectStatus(gallery, "Size 35 px, opacity 100%")
        gallery.shot("brush-keys-size")

        gallery.app.typeText("45") // 3. Two digits inside the window: exactly 45%.
        expectReadout(gallery, "Opacity 45%")
        expectStatus(gallery, "Size 35 px, opacity 45%")
        gallery.shot("brush-keys-opacity")

        let size = gallery.element("suite.gallery.brush-size") // 4. Type 9 in the size field: only the field takes it.
        size.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
        gallery.app.typeText("9")
        expectStatus(gallery, "Size 35 px, opacity 45%")
        gallery.press(.return)
        expectStatus(gallery, "Size 9 px, opacity 45%")
        gallery.shot("brush-keys-field")
    }

    /// The readout shows, and the canvas, which keeps its last text as its value, says `text` within five seconds.
    @MainActor private func expectReadout(_ gallery: Journey, _ text: String) {
        XCTAssert(gallery.element("suite.brush.readout").waitForExistence(timeout: 1), "no readout after the key")
        expectValue(gallery, "suite.gallery.brush-canvas", text)
    }

    @MainActor private func expectStatus(_ gallery: Journey, _ text: String) { expectValue(gallery, "suite.gallery.brush-status", text) }

    /// Waits up to five seconds for element `id`'s value to be `text`.
    @MainActor private func expectValue(_ gallery: Journey, _ id: String, _ text: String) {
        let element = gallery.element(id)
        let reads = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", text), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [reads], timeout: 5), .completed, "\(id) reads \(element.value ?? "nothing"), not \(text)")
    }
}
