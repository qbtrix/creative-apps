// SuiteJourneyTests+TimelineLanes.swift: SJ19e, TL-f (timeline packet, the
// dual-renderer amendment). On `timeline-long` under -SuitePerfProbe it clicks
// Lane 13's key at 12 on the AppKit lanes view and drags it 600 pt at speed
// (120 or more samples at 120 Hz, which `key-drag` proves); on `timeline` it
// moves Badge's key off the clip's end and trims that end (`trim badge end
// 40`, `trim end`). Bodies come from the perf probe's `body` marks, series
// `timeline-lane` per lane body and `timeline-window` per window body. Spec
// (packet line 487): 0 lane bodies and at most 1 window body per gesture.
// TL-20 landed it skipped; TL-23 turns it on, once the AppKit lanes view has
// its own key children (TimelineLanesView+Access). The keys it finds by
// identifier are TL-12's. Shaped after +TimelineDrag, with #2048's changes:
// the long page is `suite.gallery.timeline-long`, keys are clicked at their
// centre (a synthetic child has no hit point), a drag's steps are checked by
// their sum before one `move end`, and the trimmed end is measured from the
// lane's first key (#2450).
import AppKit
import XCTest

extension SuiteJourneyTests {
    /// SJ19e: a key drag and a trim on the AppKit lanes run no lane body and at most one window body.
    @MainActor func testTimelineLanesDragWithoutBodies() throws {
        try walkTimelineLanes()
    }

    private static let lanesFrameWidth: CGFloat = 10  // points per frame on the `timeline` page

    @MainActor private func walkTimelineLanes() throws {
        // 1. The long page: click Lane 13's key at 12, then drag it 600 pt at speed.
        let long = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline-long", "-SuitePerfProbe"])
        XCTAssert(long.element("suite.gallery.timeline-long").waitForExistence(timeout: 30), "no timeline-long page")
        let from = lanesKeySpot(12, lane: "lane-12", long)
        from.click()
        let beforeDrag = lanesBodies(long)
        // 300 pt a second, as XCUIGestureVelocity counts pixels a second.
        let velocity = XCUIGestureVelocity(300 * (NSScreen.main?.backingScaleFactor ?? 1))
        from.click(
            forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 600, dy: 0)),
            withVelocity: velocity, thenHoldForDuration: 0.05)
        long.shot("timeline-lanes-dragged")
        if let document = long.perf() { long.expectValid(document, series: "key-drag") }
        expectLanesBodies(since: beforeDrag, in: long, gesture: "the key drag")

        // 2. The short page: Badge's key at 50 moves 5 frames off the end (a key wins the press), then the end
        // at 50, measured from the lane's first key, trims 100 pt left.
        let short = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline", "-SuitePerfProbe"])
        XCTAssert(short.element("suite.gallery.timeline").waitForExistence(timeout: 30), "no timeline page")
        let log = short.element("suite.gallery.log")
        XCTAssert(log.waitForExistence(timeout: 10), "no suite.gallery.log on the timeline page")
        let badge50 = lanesKeySpot(50, lane: "badge", short)
        badge50.press(forDuration: 0.1, thenDragTo: badge50.withOffset(CGVector(dx: 5 * Self.lanesFrameWidth, dy: 0)))
        expectLanesMoves(5, log)
        XCTAssert(
            short.element("suite.timeline.key.badge.55").waitForExistence(timeout: 3), "Badge's key didn't land on 55")
        let beforeTrim = lanesBodies(short)
        let end = lanesFramePoint(50, lane: "badge", short)
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

    /// The middle of track `id`'s key at `frame`. A key is a synthetic child
    /// XCUITest finds no hit point for, so clicks go to its centre (#1796).
    @MainActor private func lanesKeySpot(_ frame: Int, lane id: String, _ gallery: Journey) -> XCUICoordinate {
        lanesKeyElement(frame, lane: id, gallery).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    }

    /// The point on track `id`'s lane at `frame`'s tick, measured from the lane's first key.
    @MainActor private func lanesFramePoint(_ frame: Int, lane id: String, _ gallery: Journey) -> XCUICoordinate {
        let lane = gallery.element("suite.timeline.lane.\(id)")
        XCTAssert(lane.waitForExistence(timeout: 5), "no lane suite.timeline.lane.\(id)")
        let first = lane.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Key at frame '")).firstMatch
        XCTAssert(first.waitForExistence(timeout: 5), "lane \(id) has no key to measure from")
        let firstFrame = Int(first.label.dropFirst("Key at frame ".count).prefix { $0.isNumber }) ?? 0
        let x = first.frame.midX + CGFloat(frame - firstFrame) * Self.lanesFrameWidth
        return lane.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x - lane.frame.minX, dy: lane.frame.height / 2))
    }

    /// Within about three seconds the log ends with one `move end`, and the `move ±n`
    /// steps right before it sum to `total`: a real drag logs a step per frame change.
    @MainActor private func expectLanesMoves(_ total: Int, _ log: XCUIElement) {
        var lines: [String] = []
        var steps: [Int] = []
        for _ in 0..<15 {
            lines = lanesLines(log)
            steps = lines.dropLast().reversed()
                .prefix { $0.hasPrefix("move +") || $0.hasPrefix("move -") }
                .compactMap { Int($0.dropFirst(5)) }
            if lines.last == "move end", steps.reduce(0, +) == total { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertEqual(lines.last, "move end", "the drag didn't end once: \(lines.suffix(8))")
        XCTAssertEqual(steps.reduce(0, +), total, "the drag's steps \(Array(steps.reversed())) don't sum to \(total)")
    }

    /// The log's lines: its value when it has one, else its label.
    @MainActor private func lanesLines(_ log: XCUIElement) -> [String] {
        let value = log.value as? String ?? ""
        return (value.isEmpty ? log.label : value).split(separator: "\n").map(String.init)
    }

    /// The log's last lines read `expected`, in order, within about three seconds.
    @MainActor private func expectLanesLog(_ expected: [String], _ log: XCUIElement) {
        var tail: [String] = []
        for _ in 0..<15 {
            tail = Array(lanesLines(log).suffix(expected.count))
            if tail == expected { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertEqual(tail, expected, "the log's last lines")
    }
}
