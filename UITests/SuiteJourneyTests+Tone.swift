// SuiteJourneyTests+Tone.swift: the gallery's `tone-rows` page (Sources/SuiteUI/Gallery/GalleryToneRows.swift),
// Journey steps 1 to 6 of docs/blueprints/suiteui/features/tone-controls.md (numbered below), in Library, shot under
// `suiteui`. TC-2 wrote it with its SJ0 part (the index lists `tone-rows` and the page opens); TC-4 turned on the steps
// after it, which drive TC-3's rows (`suite.tone.<slider>`, `suite.tone.auto`, the sections'
// `suite.inspector.section.<group>.reset`). A row's label is its title and its value the number, so VoiceOver reads
// "Shadows, 35". The page logs `<command id> <intent>` to `suite.gallery.log`.
import XCTest

final class SuiteToneJourneyTests: XCTestCase {
    @MainActor func testToneRowsSetAndReset() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        let row = gallery.element("suite.gallery.index.tone-rows") // SJ0: the index lists the page and it opens.
        XCTAssert(row.waitForExistence(timeout: 10), "the gallery index doesn't list tone-rows")
        row.click()
        XCTAssert(gallery.element("suite.gallery.tone-rows").waitForExistence(timeout: 10), "no root suite.gallery.tone-rows")
        XCTAssert(gallery.element("suite.tone").waitForExistence(timeout: 5), "the page shows no suite.tone rows")
        gallery.shot("tone-rows-open")

        // 1. Four sections, every slider at 0, Vibrance dimmed with its reason as help.
        for slider in ["temperature", "tint", "exposure", "brightness", "contrast", "highlights", "shadows", "whites",
                       "blacks", "vibrance", "saturation", "sharpenAmount", "sharpenRadius", "sharpenThreshold"]
        where !gallery.element("suite.tone.\(slider)").exists { XCTFail("no suite.tone.\(slider)") }
        XCTAssertFalse(gallery.element("suite.tone.vibrance").isEnabled, "Vibrance is enabled while it waits")

        // 2. Drag Temperature to the right: one tone.set per sample, all under one drag token.
        let temperature = gallery.element("suite.tone.temperature")
        reveal(gallery, temperature)
        let grip = temperature.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grip.press(forDuration: 0.1, thenDragTo: grip.withOffset(CGVector(dx: 40, dy: 0)))
        expectToneLog(gallery, "tone.set", "dragging Temperature logged no tone.set")
        gallery.shot("tone-rows-temperature")

        // 3. Type −40 in Highlights and 35 in Shadows: the TONE section shows its Reset.
        typeTone(gallery, "highlights", "-40")
        typeTone(gallery, "shadows", "35")
        let toneReset = gallery.element("suite.inspector.section.tone.reset")
        XCTAssert(toneReset.waitForExistence(timeout: 5), "TONE shows no Reset off neutral")

        // 4. Auto: one tone.auto.
        let auto = gallery.element("suite.tone.auto")
        reveal(gallery, auto)
        auto.click()
        expectToneLog(gallery, "tone.auto", "Auto logged no tone.auto")
        XCTAssertEqual(logLines(gallery).filter { $0.hasPrefix("tone.auto") }.count, 1, "Auto logged more than one tone.auto")

        // 5. Amount 80: Radius and Threshold enable.
        XCTAssertFalse(gallery.element("suite.tone.sharpenRadius").isEnabled, "Radius is on at Amount 0")
        typeTone(gallery, "sharpenAmount", "80")
        XCTAssert(gallery.element("suite.tone.sharpenRadius").isEnabled, "Radius stayed off at Amount 80")
        XCTAssert(gallery.element("suite.tone.sharpenThreshold").isEnabled, "Threshold stayed off at Amount 80")
        gallery.shot("tone-rows-edited")

        // 6. TONE's Reset: its rows read 0, the other sections keep theirs; rows read "<Title>, <value>".
        reveal(gallery, toneReset)
        toneReset.click()
        expectToneLog(gallery, "tone.reset", "TONE's Reset logged no tone.reset")
        let shadows = gallery.element("suite.tone.shadows")
        XCTAssertEqual(shadows.label, "Shadows", "the Shadows row isn't labelled with its title")
        XCTAssertEqual(shadows.value as? String, "0", "Shadows didn't reset")
        XCTAssertEqual(gallery.element("suite.tone.sharpenAmount").value as? String, "80", "TONE's Reset cleared Sharpen")
        gallery.shot("tone-rows-reset")
    }

    /// Types `text` into a row's field and commits it.
    @MainActor private func typeTone(_ gallery: Journey, _ slider: String, _ text: String) {
        let field = gallery.element("suite.tone.\(slider)")
        XCTAssert(field.waitForExistence(timeout: 5), "no suite.tone.\(slider)")
        reveal(gallery, field)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
        gallery.app.typeKey("a", modifierFlags: .command)
        gallery.app.typeText(text)
        gallery.press(.return)
    }

    /// Scrolls the page's rows until `element` is hittable (at most ten tries): Sharpen sits
    /// below a 768-pt runner's window (#5324).
    @MainActor private func reveal(_ gallery: Journey, _ element: XCUIElement) {
        let rows = gallery.element("suite.gallery.tone-rows.scroll")
        for _ in 0..<10 where !element.isHittable {
            rows.scroll(byDeltaX: 0, deltaY: element.frame.midY > rows.frame.midY ? -120 : 120)
        }
        XCTAssert(element.isHittable, "\(element.identifier) stays out of reach")
    }

    /// The page's log, one line per intent.
    @MainActor private func logLines(_ gallery: Journey) -> [Substring] {
        (gallery.element("suite.gallery.log").value as? String ?? "").split(separator: "\n")
    }

    /// Waits up to five seconds for a line of the page's log to start with `id`.
    @MainActor private func expectToneLog(_ gallery: Journey, _ id: String, _ message: String) {
        let log = gallery.element("suite.gallery.log")
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@ OR label CONTAINS %@", id, "\n\(id)"), object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(message); the log reads \(log.value ?? "nothing")")
    }
}
