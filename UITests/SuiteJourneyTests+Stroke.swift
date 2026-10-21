// SuiteJourneyTests+Stroke.swift: the gallery's `stroke-editor` page (Sources/SuiteUI/Gallery/GalleryStrokeEditor.swift),
// the Journey steps 1 to 5 of docs/blueprints/suiteui/features/stroke-style.md (numbered below), in Library, shot under
// `suiteui`. The editor's rows are SS-3's `suite.stroke.*`: `color` (its hex field), `width`, `join.<join>`,
// `cap.<cap>`, `dash.<preset>`, `dash-length` and `gap` (Custom), `trim-start`, `trim-end`, `trim-offset`, `add` and
// `remove`; the preview is `suite.gallery.stroke-editor.preview`; the page logs `<command id> <intent>` to
// `suite.gallery.log`. SS-2 wrote it; SS-4 turns on steps 1 to 3 on the page's own stroke (colour, width, join and cap
// apply there); steps 4 and 5 skip with "waits on SS-9", which runs them on live with dash and trim enabled.
import XCTest

final class SuiteStrokeJourneyTests: XCTestCase {
    private static let liveWait = true

    @MainActor func testStrokeEditorDashAndTrim() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.element("suite.gallery.index.stroke-editor").click() // 1. A 2 pt black stroke and every row.
        XCTAssert(gallery.element("suite.gallery.stroke-editor").waitForExistence(timeout: 10), "no suite.gallery.stroke-editor")
        let preview = gallery.element("suite.gallery.stroke-editor.preview")
        XCTAssert(preview.waitForExistence(timeout: 5), "no stroke preview")
        XCTAssertEqual(preview.value as? String, "2 pt miter butt", "the page doesn't start on a 2 pt black stroke")
        for row in ["color", "width", "join.round", "cap.round", "dash.dashed", "trim-start", "trim-end", "trim-offset"]
        where !gallery.element("suite.stroke.\(row)").exists { XCTFail("no suite.stroke.\(row)") }
        gallery.shot("stroke-editor-open")

        let hex = gallery.app.textFields.matching(NSPredicate(
            format: "identifier == %@ OR label == %@", "suite.stroke.color", "Color Hex")).firstMatch
        XCTAssert(hex.waitForExistence(timeout: 5), "no stroke Color Hex field") // 2. Red, then Width scrubbed to 6.
        hex.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        gallery.press(.rightArrow, .command)
        gallery.press(.leftArrow, [.command, .shift])
        gallery.app.typeText("FF0000")
        gallery.press(.return)
        expectStrokeLog(gallery, "stroke.color", "picking red logged no stroke.color")
        let width = gallery.element("suite.stroke.width")
        let start = width.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 40, dy: 0)))
        expectStrokeLog(gallery, "stroke.width", "the Width scrub logged no stroke.width")
        let lines = (gallery.element("suite.gallery.log").value as? String ?? "").split(separator: "\n")
        XCTAssertEqual(lines.filter { $0.hasPrefix("stroke.color") }.count, 1, "red logged more than one stroke.color")
        let drags = Set(lines.filter { $0.hasPrefix("stroke.width") }.compactMap { line in
            line.range(of: "drag: ").map { String(line[$0.upperBound...]) }
        })
        XCTAssertLessThanOrEqual(drags.count, 1, "one Width scrub logged more than one drag token")
        gallery.shot("stroke-editor-width")

        gallery.element("suite.stroke.join.round").click() // 3. Round join and Round cap.
        gallery.element("suite.stroke.cap.round").click()
        expectStrokeLog(gallery, "stroke.cap", "the Round cap chip logged no stroke.cap")
        XCTAssert((preview.value as? String ?? "").hasSuffix("round round"), "the preview's join and cap didn't round")
        gallery.shot("stroke-editor-round")

        if Self.liveWait { throw XCTSkip("waits on SS-9") } // SS-9 turns on steps 4 and 5 on live.
        gallery.element("suite.stroke.dash.dashed").click() // 4. Dashed, then Custom 10 and 4.
        expectStrokeLog(gallery, "stroke.dash", "the Dashed chip logged no stroke.dash")
        gallery.shot("stroke-editor-dashed")
        gallery.element("suite.stroke.dash.custom").click()
        for (id, text) in [("suite.stroke.dash-length", "10"), ("suite.stroke.gap", "4")] {
            gallery.element(id).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
            gallery.app.typeText(text)
            gallery.press(.return)
        }
        expectStrokeLog(gallery, "stroke.dash", "the Custom pattern logged no stroke.dash")
        gallery.shot("stroke-editor-custom-dash")
        let end = gallery.element("suite.stroke.trim-end") // 5. Trim End to 40%, Offset, Remove and Add.
        let endStart = end.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        endStart.press(forDuration: 0.1, thenDragTo: endStart.withOffset(CGVector(dx: -60, dy: 0)))
        expectStrokeLog(gallery, "stroke.trim", "the Trim End scrub logged no stroke.trim")
        gallery.shot("stroke-editor-trimmed")
        let offset = gallery.element("suite.stroke.trim-offset").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        offset.press(forDuration: 0.1, thenDragTo: offset.withOffset(CGVector(dx: 30, dy: 0)))
        expectStrokeLog(gallery, "stroke.trim", "the Offset scrub logged no stroke.trim")
        gallery.element("suite.stroke.remove").click()
        expectStrokeLog(gallery, "stroke.remove", "Remove Stroke logged nothing")
        XCTAssertEqual(preview.value as? String, "No stroke", "Remove Stroke left a stroke")
        gallery.shot("stroke-editor-no-stroke")
        gallery.element("suite.stroke.add").click()
        expectStrokeLog(gallery, "stroke.add", "Add Stroke logged nothing")
        XCTAssertEqual(preview.value as? String, "1 pt miter butt", "Add Stroke didn't bring back a 1 pt black stroke")
        gallery.shot("stroke-editor-added")
    }

    /// Waits up to five seconds for a line of the page's log to start with `id`.
    @MainActor private func expectStrokeLog(_ gallery: Journey, _ id: String, _ message: String) {
        let log = gallery.element("suite.gallery.log")
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@ OR label CONTAINS %@", id, "\n\(id)"), object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(message); the log reads \(log.value ?? "nothing")")
    }
}
