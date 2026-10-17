// SuiteJourneyTests+Timeline.swift: SJ19a and SP3, TL-b (timeline packet,
// Journey steps 2 and 3). SJ19a on `timeline` hovers a key, selects Shadow by
// its name, scrubs from the playhead line inside Badge's lane and from the
// ruler, then scrolls `timeline-long` under its pinned ruler. SP3 drags the
// pill 600 pt across `timeline-long`, series `timeline-scrub`, report-only.
// TL-5 wrote both skipped; TL-8 turns them on. The ruler is SuiteUI's own
// `suite.timeline.ruler`; lanes, keys and names are found by the identifiers
// the gallery opts into (`suite.timeline.lane.<id>`, `.key.<id>.<frame>`,
// `.name.<id>`), since XCUITest reads a lane's value as "" (#262, #1800).
import XCTest

extension SuiteJourneyTests {
    /// SJ19a: the strip looks right idle and hovered, scrubs from a lane and the ruler, and keeps the ruler pinned.
    @MainActor func testTimelineLooksAndScrubs() throws {
        try walkTimelineLook()
    }

    /// SP3: a fast drag of the playhead pill across 600 pt of `timeline-long`; report-only (QB-S5).
    @MainActor func testTimelineScrubLatency() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline-long", "-SuitePerfProbe"])
        let ruler = gallery.element("suite.timeline.ruler")
        XCTAssert(ruler.waitForExistence(timeout: 30), "timeline-long has no ruler (suite.timeline.ruler)")
        // A click puts the pill under the pointer; then the pill is dragged 600 pt at 300 pt a second.
        let pill = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 40, dy: 0))
        pill.click()
        pill.click(forDuration: 0.05, thenDragTo: pill.withOffset(CGVector(dx: 600, dy: 0)),
                   withVelocity: 300, thenHoldForDuration: 0.05)
        gallery.shot("timeline-scrub-perf")
        if let document = gallery.perf() { gallery.expectValid(document, series: "timeline-scrub") }
    }

    @MainActor private func walkTimelineLook() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline"])
        let ruler = gallery.element("suite.timeline.ruler")
        XCTAssert(ruler.waitForExistence(timeout: 30), "timeline has no ruler (suite.timeline.ruler)")
        let log = gallery.element("suite.gallery.log")
        gallery.shot("timeline-idle")
        // 1. Hover Ball's key at 12: the shot shows the hover ring.
        let ball12 = lookKey(12, lane: "ball", gallery)
        ball12.hover()
        gallery.shot("timeline-hover")
        // 2. Click Shadow's name: the track is selected.
        gallery.element("suite.timeline.name.shadow").click()
        expectLookLog("track shadow", log)
        // 3. Press on the playhead line inside Badge's lane (frame 30, 10 pt a frame) and drag 120 pt left.
        let badge = lookLane("badge", gallery)
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
        let longRuler = long.element("suite.timeline.ruler")
        XCTAssert(longRuler.waitForExistence(timeout: 30), "timeline-long has no ruler")
        let rulerY = longRuler.frame.minY
        longRuler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 6)).scroll(byDeltaX: 0, deltaY: -2_000)
        XCTAssertEqual(longRuler.frame.minY, rulerY, accuracy: 1, "the ruler moved with the lanes")
        // Lane ids are `lane-<row>`, rows from 0: row 60 is the 61st lane.
        let deep = long.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'suite.timeline.lane.lane-'")).allElementsBoundByIndex
            .filter { $0.isHittable }
        XCTAssert(
            deep.contains { (Int($0.identifier.split(separator: "-").last ?? "") ?? 0) >= 60 },
            "no lane past the 60th is hittable")
        long.shot("timeline-long-scrolled")
        long.drag(on: "suite.timeline.ruler", from: CGVector(dx: 0.2, dy: 0.5), to: CGVector(dx: 0.4, dy: 0.5))
        let longLog = long.element("suite.gallery.log")
        XCTAssert(lookWait { self.lookLastLine(longLog).hasPrefix("scrub ") }, "the ruler drag logged \(lookLastLine(longLog))")
    }

    /// The lane of track `id`, `suite.timeline.lane.<id>`.
    @MainActor private func lookLane(_ id: String, _ gallery: Journey) -> XCUIElement {
        let lane = gallery.element("suite.timeline.lane.\(id)")
        XCTAssert(lane.waitForExistence(timeout: 5), "no lane suite.timeline.lane.\(id)")
        return lane
    }

    /// The key at `frame` on track `id`'s lane, `suite.timeline.key.<id>.<frame>`.
    @MainActor private func lookKey(_ frame: Int, lane id: String, _ gallery: Journey) -> XCUIElement {
        let key = gallery.element("suite.timeline.key.\(id).\(frame)")
        XCTAssert(key.waitForExistence(timeout: 5), "no key suite.timeline.key.\(id).\(frame)")
        return key
    }

    @MainActor private func expectLookLog(_ line: String, _ log: XCUIElement) {
        XCTAssert(lookWait { self.lookLastLine(log) == line }, "the log's last line reads \(lookLastLine(log)), not \(line)")
    }

    /// The last line of what an element reads: its value when it has one, else its label.
    @MainActor private func lookLastLine(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return (value.isEmpty ? element.label : value).split(separator: "\n").last.map(String.init) ?? ""
    }

    /// Whether `condition` holds within about three seconds.
    @MainActor private func lookWait(_ condition: () -> Bool) -> Bool {
        (0..<15).contains { _ in condition() || { Thread.sleep(forTimeInterval: 0.2); return false }() } || condition()
    }
}
