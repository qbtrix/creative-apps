// SuiteJourneyTests+TimelineLanes.swift: SJ19e, TL-f (timeline packet, the
// dual-renderer amendment). On `timeline-long` under -SuitePerfProbe it clicks
// Lane 13's key at 12 on the AppKit lanes view and drags it 600 pt at speed
// (120 or more samples at 120 Hz, which `key-drag` proves); on `timeline` it
// moves Badge's key off the clip's end and trims that end (`trim badge end
// 40`, `trim end`). Bodies come from the perf probe: TL-23's lanes view
// records a `body` mark in series `timeline-lane` per lane body, the gallery
// page one in `timeline-window` per window body. Spec (packet line 487): 0
// lane bodies and at most 1 window body per gesture. TL-20 lands it skipped;
// TL-23 turns it on. Shaped after +TimelineDrag.
import AppKit
import XCTest

extension SuiteJourneyTests {
    /// SJ19e: a key drag and a trim on the AppKit lanes run no lane body and at most one window body.
    @MainActor func testTimelineLanesDragWithoutBodies() throws {
        throw XCTSkip("waits on TL-23")
        try walkTimelineLanes()
    }

    private static let lanesFrameWidth: CGFloat = 10  // points per frame on the `timeline` page

    @MainActor private func walkTimelineLanes() throws {
        // 1. The long page: click Lane 13's key at 12, then drag it 600 pt at speed.
        let long = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline-long", "-SuitePerfProbe"])
        XCTAssert(long.element("suite.gallery.timeline").waitForExistence(timeout: 30), "no timeline-long page")
        let key = lanesKeyElement(12, lane: "lane-12", long)
        key.click()
        let beforeDrag = lanesBodies(long)
        let from = key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // 300 pt a second, as XCUIGestureVelocity counts pixels a second.
        let velocity = XCUIGestureVelocity(300 * (NSScreen.main?.backingScaleFactor ?? 1))
        from.click(
            forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 600, dy: 0)),
            withVelocity: velocity, thenHoldForDuration: 0.05)
        long.shot("timeline-lanes-dragged")
        if let document = long.perf() { long.expectValid(document, series: "key-drag") }
        expectLanesBodies(since: beforeDrag, in: long, gesture: "the key drag")

        // 2. The short page: Badge's key at 50 moves 5 frames off the end (a key wins the press), then the end,
        // 50 pt left of that key's new tick, trims 100 pt left.
        let short = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline", "-SuitePerfProbe"])
        XCTAssert(short.element("suite.gallery.timeline").waitForExistence(timeout: 30), "no timeline page")
        let log = short.element("suite.gallery.log")
        XCTAssert(log.waitForExistence(timeout: 10), "no suite.gallery.log on the timeline page")
        let badge50 = lanesKeyElement(50, lane: "badge", short).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        badge50.press(forDuration: 0.1, thenDragTo: badge50.withOffset(CGVector(dx: 5 * Self.lanesFrameWidth, dy: 0)))
        expectLanesLog(["move +5", "move end"], log)
        let beforeTrim = lanesBodies(short)
        let end = lanesKeyElement(55, lane: "badge", short).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: -5 * Self.lanesFrameWidth, dy: 0))
        end.press(forDuration: 0.1, thenDragTo: end.withOffset(CGVector(dx: -100, dy: 0)))
        expectLanesLog(["trim badge end 40", "trim end"], log)
        short.shot("timeline-lanes-trimmed")
        expectLanesBodies(since: beforeTrim, in: short, gesture: "the trim")
    }

    /// The lane and window body counts the probe has recorded so far; nil (and a failure) without the probe.
    @MainActor private func lanesBodies(_ gallery: Journey) -> (lanes: Int, window: Int)? {
        guard let document = gallery.perf() else { return nil }
        let bodies = document.marks.filter { $0.name == "body" }
        return (bodies.filter { $0.series == "timeline-lane" }.count, bodies.filter { $0.series == "timeline-window" }.count)
    }

    /// The bodies since `before`: 0 lane bodies and at most 1 window body (packet line 487).
    @MainActor private func expectLanesBodies(since before: (lanes: Int, window: Int)?, in gallery: Journey, gesture: String) {
        guard let before, let after = lanesBodies(gallery) else { return }
        XCTAssertEqual(after.lanes - before.lanes, 0, "\(gesture) ran lane bodies")
        XCTAssertLessThanOrEqual(after.window - before.window, 1, "\(gesture) ran more than one window body")
    }

    /// The key at `frame` on track `id`'s lane, `suite.timeline.key.<id>.<frame>`.
    @MainActor private func lanesKeyElement(_ frame: Int, lane id: String, _ gallery: Journey) -> XCUIElement {
        let key = gallery.element("suite.timeline.key.\(id).\(frame)")
        XCTAssert(key.waitForExistence(timeout: 5), "no key suite.timeline.key.\(id).\(frame)")
        return key
    }

    /// The log's last lines read `expected`, in order, within about three seconds.
    @MainActor private func expectLanesLog(_ expected: [String], _ log: XCUIElement) {
        var tail: [String] = []
        for _ in 0..<15 {
            let value = log.value as? String ?? ""
            tail = Array((value.isEmpty ? log.label : value).split(separator: "\n").map(String.init).suffix(expected.count))
            if tail == expected { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertEqual(tail, expected, "the log's last lines")
    }
}
