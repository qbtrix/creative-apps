// SuiteJourneyTests+Timeline.swift: SJ19a and SP3, TL-b (packet
// docs/blueprints/suiteui/features/timeline.md, Journey steps 2 and 3). SJ19a
// on `timeline` (10 pt per frame, playhead 30): hover Ball's key at 12 (the
// hover ring), click Shadow's name (log `track shadow`), press on the playhead
// line inside Badge's lane and drag 120 pt left (log `scrub 18`, the pill
// reads 18), drag on the ruler to frame 30 (log `scrub 30`); then on
// `timeline-long` scroll the lanes down 2,000 pt with the wheel (the ruler
// stays put, a lane past the 60th is hittable) and drag on the ruler again.
// SP3 drags the playhead pill 600 pt across `timeline-long` at speed, series
// `timeline-scrub`, report-only. Written before its code (lead.md, contract
// rule 13): TL-5 lands both skipped, TL-8 turns them on.
import XCTest

extension SuiteJourneyTests {
    /// SJ19a: the strip looks right idle and hovered, scrubs from a lane and the ruler, and keeps the ruler pinned.
    @MainActor func testTimelineLooksAndScrubs() throws {
        throw XCTSkip("waits on TL-8")
        try walkTimelineLook()
    }

    /// SP3: a fast drag of the playhead pill across 600 pt of `timeline-long`; report-only (QB-S5).
    @MainActor func testTimelineScrubLatency() throws {
        throw XCTSkip("waits on TL-8")
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline-long", "-SuitePerfProbe"])
        let ruler = gallery.element("suite.gallery.timeline.ruler")
        XCTAssert(ruler.waitForExistence(timeout: 30), "timeline-long has no ruler (suite.gallery.timeline.ruler)")
        let start = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 40, dy: 0))
        start.click()
        start.click(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 600, dy: 0)),
                    withVelocity: 300, thenHoldForDuration: 0.05)
        gallery.shot("timeline-scrub-perf")
        if let document = gallery.perf() { gallery.expectValid(document, series: "timeline-scrub") }
    }

    @MainActor private func walkTimelineLook() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline"])
        let ruler = gallery.element("suite.gallery.timeline.ruler")
        XCTAssert(ruler.waitForExistence(timeout: 30), "timeline has no ruler (suite.gallery.timeline.ruler)")
        let log = gallery.element("suite.gallery.log")
        XCTAssert(log.waitForExistence(timeout: 10), "no suite.gallery.log on the timeline page")
        gallery.shot("timeline-idle")

        // 1. Hover Ball's key at 12: the shot shows the hover ring.
        let ball12 = lookKey(12, lane: "Ball", gallery)
        ball12.hover()
        gallery.shot("timeline-hover")

        // 2. Click Shadow's name: the track is selected.
        gallery.app.buttons["Shadow"].firstMatch.click()
        expectLookLog("track shadow", log)

        // 3. Press on the playhead line inside Badge's lane (frame 30, 10 pt a frame) and drag 120 pt left.
        let badge = lookLane("Badge", gallery)
        let lineX = ball12.frame.midX + 18 * 10
        let onLine = badge.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: lineX - badge.frame.minX, dy: badge.frame.height / 2))
        onLine.press(forDuration: 0.1, thenDragTo: onLine.withOffset(CGVector(dx: -120, dy: 0)))
        expectLookLog("scrub 18", log)
        XCTAssert(gallery.app.staticTexts["18"].firstMatch.waitForExistence(timeout: 3), "the pill doesn't read 18")

        // 4. Drag on the ruler back to frame 30.
        let rulerAt18 = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .withOffset(CGVector(dx: lineX - 120 - ruler.frame.minX, dy: 0))
        rulerAt18.press(forDuration: 0.1, thenDragTo: rulerAt18.withOffset(CGVector(dx: 120, dy: 0)))
        expectLookLog("scrub 30", log)

        // 5. timeline-long: the wheel scrolls the lanes 2,000 pt down under a pinned ruler.
        gallery.app.terminate()
        let long = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline-long"])
        let longRuler = long.element("suite.gallery.timeline.ruler")
        XCTAssert(longRuler.waitForExistence(timeout: 30), "timeline-long has no ruler")
        let rulerY = longRuler.frame.minY
        longRuler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 6)).scroll(byDeltaX: 0, deltaY: -2_000)
        XCTAssertEqual(longRuler.frame.minY, rulerY, accuracy: 1, "the ruler moved with the lanes")
        let deep = long.app.descendants(matching: .any).matching(
            NSPredicate(format: "value CONTAINS 'keyframe'")).allElementsBoundByIndex.filter { $0.isHittable }
        XCTAssert(deep.contains { (Int($0.label.filter(\.isNumber)) ?? 0) > 60 }, "no lane past the 60th is hittable")
        long.shot("timeline-long-scrolled")
        long.drag(on: "suite.gallery.timeline.ruler", from: CGVector(dx: 0.2, dy: 0.5), to: CGVector(dx: 0.4, dy: 0.5))
        let longLog = long.element("suite.gallery.log")
        XCTAssert(lookWait { self.lookLastLine(longLog).hasPrefix("scrub ") }, "the ruler drag logged \(lookLastLine(longLog))")
    }

    /// The lane of track `name`: its label is the name and its value counts keyframes.
    @MainActor private func lookLane(_ name: String, _ gallery: Journey) -> XCUIElement {
        let lane = gallery.app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ AND value CONTAINS 'keyframe'", name)).firstMatch
        XCTAssert(lane.waitForExistence(timeout: 5), "no lane for \(name)")
        return lane
    }

    /// The key at `frame` on `name`'s lane ("Key at frame <n>, <shape>").
    @MainActor private func lookKey(_ frame: Int, lane name: String, _ gallery: Journey) -> XCUIElement {
        let key = lookLane(name, gallery).descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Key at frame \(frame),")).firstMatch
        XCTAssert(key.waitForExistence(timeout: 5), "no key at \(frame) on \(name)'s lane")
        return key
    }

    /// The log's last line reads `line` within about three seconds.
    @MainActor private func expectLookLog(_ line: String, _ log: XCUIElement) {
        XCTAssert(lookWait { self.lookLastLine(log) == line }, "the log's last line reads \(lookLastLine(log)), not \(line)")
    }

    /// The last line of what an element reads: its value when it has one, else its label.
    @MainActor private func lookLastLine(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        let text = value.isEmpty ? element.label : value
        return text.split(separator: "\n").last.map(String.init) ?? ""
    }

    /// Whether `condition` holds within about three seconds.
    @MainActor private func lookWait(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
