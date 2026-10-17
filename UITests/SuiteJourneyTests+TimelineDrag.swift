// SuiteJourneyTests+TimelineDrag.swift: SJ19c and SP8, TL-d (packet
// docs/blueprints/suiteui/features/timeline.md, Journey steps 5 and 6). SJ19c,
// on `timeline` at 10 pt per frame: key drags log `move +n` steps and one
// `move end`, a pick moves as a group, a drag past the end stops on frame 59,
// a key 6 pt short of the playhead snaps onto it, and Badge's clip ends trim
// (`trim badge end 40`, `trim badge start 25`, `trim end`). SP8 drags a key
// 600 pt at speed on `timeline-long` and reports `key-drag` (QB-S5,
// report-only). TL-13 landed both skipped; TL-15 turned them on. A key wins a
// press over a clip end (hit priority), and Badge has keys on both its ends, so
// the trim step first drags those keys 5 frames off the ends. Lanes and keys
// are found by identifier as in +TimelineKeys (`suite.timeline.lane.<id>`,
// `suite.timeline.key.<id>.<frame>`); a frame's x comes from a key's tick. SP8
// drags Lane 13's (`lane-12`) key at 12, the long page's lanes being
// "Lane 1"…"Lane 300".
import AppKit
import XCTest

extension SuiteJourneyTests {
    /// SJ19c: picked keys drag as a group with snapping, and a clip's ends trim.
    @MainActor func testTimelineDragsKeysAndTrimsClips() throws {
        try walkTimelineDrags()
    }

    /// SP8: a velocity drag of a picked key across 600 pt reports `key-drag` (QB-S5, report-only).
    @MainActor func testKeyDragLatency() throws {
        try measureKeyDrag()
    }

    /// Points per frame on the `timeline` page.
    private static let dragFrameWidth: CGFloat = 10

    @MainActor private func walkTimelineDrags() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline"])
        XCTAssert(gallery.element("suite.gallery.timeline").waitForExistence(timeout: 30), "no timeline page")
        let log = gallery.element("suite.gallery.log")
        XCTAssert(log.waitForExistence(timeout: 10), "no suite.gallery.log on the timeline page")

        // 1. Ball's key at 12 by 52 pt: five frames, one step, one end.
        dragKey(12, lane: "ball", by: 52, gallery)
        expectDragLog(["move +5", "move end"], log)
        XCTAssert(dragKeyExists(17, lane: "ball", gallery), "Ball's key didn't land on 17")

        // 2. Pick Ball's 24 and 36, drag 24 by 30 pt: both move three frames.
        dragKeyElement(24, lane: "ball", gallery).click()
        let ball36 = dragKeyElement(36, lane: "ball", gallery)
        XCUIElement.perform(withKeyModifiers: .shift) { ball36.click() }
        dragKey(24, lane: "ball", by: 30, gallery)
        expectDragLog(["move +3", "move end"], log)
        XCTAssert(dragKeyExists(27, lane: "ball", gallery) && dragKeyExists(39, lane: "ball", gallery), "the pick didn't move as a group")

        // 3. Ball's last key, now 39, 400 pt right: it stops on 59, and the steps sum to +20.
        let before = dragLines(log).count
        dragKey(39, lane: "ball", by: 400, gallery)
        Thread.sleep(forTimeInterval: 0.5)
        let lines = Array(dragLines(log).dropFirst(before))
        XCTAssertEqual(lines.last, "move end", "the clamped drag didn't end once: \(lines)")
        let sum = lines.compactMap { $0.hasPrefix("move +") || $0.hasPrefix("move -") ? Int($0.dropFirst(5)) : nil }.reduce(0, +)
        XCTAssertEqual(sum, 20, "the clamped drag's steps sum to \(sum), not 59 - 39: \(lines)")
        XCTAssert(dragKeyExists(59, lane: "ball", gallery), "Ball's last key didn't stop on frame 59")

        // 4. Shadow's key at 12 to 6 pt short of the playhead at 30: it snaps onto 30.
        dragKey(12, lane: "shadow", by: (30 - 12) * Self.dragFrameWidth - 6, gallery)
        expectDragLog(["move +18", "move end"], log)
        XCTAssert(dragKeyExists(30, lane: "shadow", gallery), "Shadow's key didn't snap to the playhead at 30")
        gallery.shot("timeline-dragged")

        // 5. Badge's clip 20–50: its keys at 50 and 20 move off the ends (a key wins the press),
        // then hover its right end (resize cursor), trim it 100 pt left, then its left end 50 pt right.
        dragKey(50, lane: "badge", by: 5 * Self.dragFrameWidth, gallery)
        expectDragLog(["move +5", "move end"], log)
        dragKey(20, lane: "badge", by: -5 * Self.dragFrameWidth, gallery)
        expectDragLog(["move -5", "move end"], log)
        let end = dragFramePoint(50, lane: "badge", gallery)
        end.hover()
        gallery.shot("timeline-trim-hover")
        end.press(forDuration: 0.1, thenDragTo: end.withOffset(CGVector(dx: -100, dy: 0)))
        expectDragLog(["trim badge end 40", "trim end"], log)
        let start = dragFramePoint(20, lane: "badge", gallery)
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 50, dy: 0)))
        expectDragLog(["trim badge start 25", "trim end"], log)
        gallery.shot("timeline-trimmed")
    }

    @MainActor private func measureKeyDrag() throws {
        let gallery = Journey(
            "Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline-long", "-SuitePerfProbe"])
        XCTAssert(gallery.element("suite.gallery.timeline").waitForExistence(timeout: 30), "no timeline-long page")
        let key = dragKeyElement(12, lane: "lane-12", gallery)
        key.click()
        let from = key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // 300 pt a second, as XCUIGestureVelocity counts pixels a second.
        let velocity = XCUIGestureVelocity(300 * (NSScreen.main?.backingScaleFactor ?? 1))
        from.click(
            forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 600, dy: 0)),
            withVelocity: velocity, thenHoldForDuration: 0.05)
        gallery.shot("timeline-key-drag-perf")
        guard let document = gallery.perf() else { return }
        gallery.expectValid(document, series: "key-drag")
    }

    /// Drags track `id`'s key at `frame` sideways by `dx` points from its middle.
    @MainActor private func dragKey(_ frame: Int, lane id: String, by dx: CGFloat, _ gallery: Journey) {
        let from = dragKeyElement(frame, lane: id, gallery).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: dx, dy: 0)))
    }

    /// The point on track `id`'s lane at `frame`'s tick, measured from the lane's first key.
    @MainActor private func dragFramePoint(_ frame: Int, lane id: String, _ gallery: Journey) -> XCUICoordinate {
        let lane = dragLane(id, gallery)
        let first = lane.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Key at frame '")).firstMatch
        XCTAssert(first.waitForExistence(timeout: 5), "lane \(id) has no key to measure from")
        let firstFrame = Int(first.label.dropFirst("Key at frame ".count).prefix { $0.isNumber }) ?? 0
        let x = first.frame.midX + CGFloat(frame - firstFrame) * Self.dragFrameWidth
        return lane.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x - lane.frame.minX, dy: lane.frame.height / 2))
    }

    /// The lane of track `id`, `suite.timeline.lane.<id>`.
    @MainActor private func dragLane(_ id: String, _ gallery: Journey) -> XCUIElement {
        let lane = gallery.element("suite.timeline.lane.\(id)")
        XCTAssert(lane.waitForExistence(timeout: 5), "no lane suite.timeline.lane.\(id)")
        return lane
    }

    /// The key at `frame` on track `id`'s lane, `suite.timeline.key.<id>.<frame>`.
    @MainActor private func dragKeyElement(_ frame: Int, lane id: String, _ gallery: Journey) -> XCUIElement {
        let key = gallery.element("suite.timeline.key.\(id).\(frame)")
        XCTAssert(key.waitForExistence(timeout: 5), "no key suite.timeline.key.\(id).\(frame)")
        return key
    }

    /// Whether track `id`'s lane has a key at `frame` within about three seconds.
    @MainActor private func dragKeyExists(_ frame: Int, lane id: String, _ gallery: Journey) -> Bool {
        gallery.element("suite.timeline.key.\(id).\(frame)").waitForExistence(timeout: 3)
    }

    /// The log's last lines read `expected`, in order, within about three seconds.
    @MainActor private func expectDragLog(_ expected: [String], _ log: XCUIElement) {
        var tail: [String] = []
        for _ in 0..<15 {
            tail = Array(dragLines(log).suffix(expected.count))
            if tail == expected { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertEqual(tail, expected, "the log's last lines")
    }

    /// The log's lines: its value when it has one, else its label.
    @MainActor private func dragLines(_ log: XCUIElement) -> [String] {
        let value = log.value as? String ?? ""
        return (value.isEmpty ? log.label : value).split(separator: "\n").map(String.init)
    }
}
