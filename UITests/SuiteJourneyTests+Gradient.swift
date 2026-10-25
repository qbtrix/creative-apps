// SuiteJourneyTests+Gradient.swift: the gallery's `gradient-editor` page (Sources/SuiteUI/Gallery/GalleryGradientEditor.swift),
// Journey steps 1 to 6 of docs/blueprints/suiteui/features/gradient-fill.md (numbered below), in Library, shot under
// `suiteui`. The editor's controls are GF-3's `suite.gradient.*`: `bar` (the stop bar), `stop.<n>` (each handle, from 0),
// `color` (the selected stop's hex field), `angle`, `type.<solid|linear|radial>` and `help`; the preview is
// `suite.gallery.gradient-editor.preview`, its value "<type>, <n> stops, <angle>°"; the page logs `<command id> <intent>`
// to `suite.gallery.log`. On since GF-4.
import XCTest

final class SuiteGradientJourneyTests: XCTestCase {
    @MainActor func testGradientEditorEditsAFill() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.element("suite.gallery.index.gradient-editor").click() // 1. A two-stop linear fill, blue to white, 0°.
        XCTAssert(gallery.element("suite.gallery.gradient-editor").waitForExistence(timeout: 10), "no suite.gallery.gradient-editor")
        let preview = gallery.element("suite.gallery.gradient-editor.preview")
        XCTAssert(preview.waitForExistence(timeout: 5), "no gradient preview")
        XCTAssertEqual(preview.value as? String, "linear, 2 stops, 0°", "the page doesn't start on a two-stop linear fill")
        for control in ["bar", "stop.0", "stop.1", "color", "angle", "type.solid", "type.linear", "type.radial"]
        where !gallery.element("suite.gradient.\(control)").exists { XCTFail("no suite.gradient.\(control)") }
        gallery.shot("gradient-editor-open")

        let bar = gallery.element("suite.gradient.bar") // 2. A click mid-bar adds a selected third stop.
        bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        expectGradientLog(gallery, "fill.stop-add", "a click on the bar logged no fill.stop-add")
        XCTAssertEqual(preview.value as? String, "linear, 3 stops, 0°", "the click didn't add a stop")
        XCTAssert(gallery.element("suite.gradient.stop.2").exists, "no third stop handle")
        gallery.shot("gradient-editor-three-stops")

        let hex = gallery.app.textFields.matching(NSPredicate( // 3. Red in the colour row: one fill.stop-color.
            format: "identifier == %@ OR label == %@", "suite.gradient.color", "Color Hex")).firstMatch
        XCTAssert(hex.waitForExistence(timeout: 5), "no gradient Color Hex field")
        hex.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        gallery.press(.rightArrow, .command)
        gallery.press(.leftArrow, [.command, .shift])
        gallery.app.typeText("FF0000")
        gallery.press(.return)
        expectGradientLog(gallery, "fill.stop-color", "picking red logged no fill.stop-color")
        XCTAssertEqual(logLines(gallery).filter { $0.hasPrefix("fill.stop-color") }.count, 1, "red logged more than one fill.stop-color")
        XCTAssertEqual(gallery.element("suite.gradient.stop.1").label, "Stop 2 of 3, 50 percent, red") // 6. VoiceOver.
        gallery.shot("gradient-editor-red")

        let stop = gallery.element("suite.gradient.stop.1") // 4. Drag the stop to 25%: one drag token.
        let from = stop.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: bar.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)))
        expectGradientLog(gallery, "fill.stop-move", "the stop drag logged no fill.stop-move")
        let tokens = Set(logLines(gallery).filter { $0.hasPrefix("fill.stop-move") }.compactMap { line in
            line.range(of: "drag: ").map { String(line[$0.upperBound...]) }
        })
        XCTAssertEqual(tokens.count, 1, "one stop drag logged more than one drag token")

        let angle = gallery.element("suite.gradient.angle") // 5. 45°, Radial hides the angle, back to Linear.
        angle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
        gallery.app.typeText("45")
        gallery.press(.return)
        expectGradientLog(gallery, "fill.angle", "typing 45 logged no fill.angle")
        gallery.element("suite.gradient.type.radial").click()
        expectGradientLog(gallery, "fill.type", "Radial logged no fill.type")
        XCTAssertFalse(gallery.element("suite.gradient.angle").exists, "the angle row shows for a radial fill")
        gallery.shot("gradient-editor-radial")
        gallery.element("suite.gradient.type.linear").click() // Radial to Linear keeps the stops; the line starts at 0°.
        XCTAssert((preview.value as? String ?? "").hasPrefix("linear, 3 stops"), "back to Linear lost a stop")
        let red = gallery.element("suite.gradient.stop.1")
        let grip = red.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grip.press(forDuration: 0.1, thenDragTo: grip.withOffset(CGVector(dx: 0, dy: 60)))
        expectGradientLog(gallery, "fill.stop-remove", "dragging the stop off logged no fill.stop-remove")
        XCTAssert((preview.value as? String ?? "").hasPrefix("linear, 2 stops"), "dragging the stop off left three stops")

        gallery.element("suite.gradient.stop.0").click() // 6. Two stops: Delete does nothing and the help reads.
        gallery.press(.delete)
        XCTAssert((preview.value as? String ?? "").hasPrefix("linear, 2 stops"), "Delete removed one of two stops")
        XCTAssertEqual(gallery.element("suite.gradient.help").label, "A gradient needs at least two stops.")
        gallery.press(.rightArrow)
        expectGradientLog(gallery, "fill.stop-move", "the right arrow logged no fill.stop-move")
        gallery.shot("gradient-editor-two-stops-help")
    }

    /// The page's log, one line per intent.
    @MainActor private func logLines(_ gallery: Journey) -> [Substring] {
        (gallery.element("suite.gallery.log").value as? String ?? "").split(separator: "\n")
    }

    /// Waits up to five seconds for a line of the page's log to start with `id`.
    @MainActor private func expectGradientLog(_ gallery: Journey, _ id: String, _ message: String) {
        let log = gallery.element("suite.gallery.log")
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@ OR label CONTAINS %@", id, "\n\(id)"), object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(message); the log reads \(log.value ?? "nothing")")
    }
}
