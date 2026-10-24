// SuiteJourneyTests+Eyedropper.swift (eyedropper EY-2 written, EY-4 turns on): the packet's journey steps 2 to 5
// on the gallery's `eyedropper` page. The button opens the system sampler and a click on the red swatch sets the
// row; Escape picks nothing; the page's tool shows the loupe over green; 5 × 5 reads the mean at the swatch edge.
// On since EY-4; steps 4 and 5 need the page's tool (EY-7).
import XCTest

final class SuiteEyedropperJourneyTests: XCTestCase {
    static let page = "eyedropper"

    @MainActor func testEyedropperPicksFromCanvas() throws {
        let gallery = Journey(
            "Library", self, name: "suiteui", arguments: ["-SuiteGallery", Self.page, "-SuiteGalleryFakes", "-SuitePerfProbe"])
        XCTAssert(gallery.element("suite.gallery.\(Self.page)").waitForExistence(timeout: 30), "no \(Self.page) page")
        gallery.shot("eyedropper-row")
        let hex = gallery.element("suite.gallery.eyedropper.hex")
        let log = gallery.element("suite.gallery.eyedropper.log")
        let red = gallery.element("suite.gallery.eyedropper.red")
        XCTAssert(red.waitForExistence(timeout: 5), "no red swatch on the page")

        // Step 2: the button opens the sampler; a click on the red swatch sets the row in one change and one end.
        let button = gallery.element("suite.color.eyedropper")
        XCTAssert(button.waitForExistence(timeout: 5), "no eyedropper button on the colour row")
        button.click()
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        // The sampler answers asynchronously: the row reads red a moment after the click (#3852 read it at once).
        let picked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "#FF0000"), object: hex)
        _ = XCTWaiter().wait(for: [picked], timeout: 5)
        XCTAssertEqual(value(hex), "#FF0000", "the row after picking red")
        XCTAssertEqual(lines(log), ["change #FF0000", "end"], "the log after picking red")
        gallery.shot("eyedropper-picked")

        // Step 3: Escape in the sampler picks nothing.
        button.click()
        gallery.app.typeKey(.escape, modifierFlags: [])
        XCTAssertEqual(value(hex), "#FF0000", "the row after Escape")
        XCTAssertEqual(lines(log).count, 2, "Escape logged something: \(lines(log))")

        // Step 4: the page's tool shows the loupe over green and a click sets the row through color.sample.
        gallery.element("suite.gallery.eyedropper.tool").click()
        let green = gallery.element("suite.gallery.eyedropper.green")
        green.hover()
        let loupe = gallery.element("suite.sample.loupe")
        XCTAssert(loupe.waitForExistence(timeout: 5), "no loupe over the green swatch")
        XCTAssertEqual(loupe.label, "#00FF00", "the loupe over green")
        gallery.shot("eyedropper-loupe")
        green.click()
        XCTAssertEqual(value(hex), "#00FF00", "the row after the tool's click")
        XCTAssert(lines(log).last?.hasPrefix("color.sample") == true, "the tool's click didn't sample: \(lines(log))")

        // Step 5: 5 × 5 at the swatch edge reads the mean of what it covers, not the pixel under the point.
        let five = gallery.element("suite.sample.size.5")
        XCTAssert(five.waitForExistence(timeout: 5), "no 5 × 5 size chip")
        five.click()
        gallery.shot("eyedropper-sizes")
        green.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).click()
        XCTAssertNotEqual(value(hex), "#00FF00", "5 × 5 at the edge read only the pixel under the point")
        XCTAssertEqual(button.label, "Pick a colour from the screen", "the button's VoiceOver label")
    }

    /// The hex field's text: macOS gives a field's string as `value`.
    @MainActor private func value(_ field: XCUIElement) -> String { field.value as? String ?? "" }

    /// The page log's lines, oldest first.
    @MainActor private func lines(_ log: XCUIElement) -> [String] {
        let text = log.label.isEmpty ? log.value as? String ?? "" : log.label
        return text.split(separator: "\n").map(String.init)
    }
}
