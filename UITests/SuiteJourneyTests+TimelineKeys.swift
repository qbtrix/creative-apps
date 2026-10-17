// SuiteJourneyTests+TimelineKeys.swift: SJ19b, TL-c (packet
// docs/blueprints/suiteui/features/timeline.md, Journey steps 4). On the
// `timeline` gallery page it picks keys with the mouse: a click on Ball's key
// at 12 (log `pick ball 12 replace`, the key's element selected), Shift-click
// 24 (`extend`), ⌘-click 12 (`toggle`), a right-click on Shadow's 36
// (`pick shadow 36 replace` and the page's menu shows "Ease In"), a click on
// Ball's empty bed (`pick ball none`). Then the keyboard: Ball's key at 0 and
// → twice picks 24, ← at the first key changes nothing. Then VoiceOver: the
// element "Key at frame 36, eased" on Shadow's lane picks it by its default
// action, and Badge's lane reads "Frames 20–50, 3 keyframes at 20, 30, 50".
// Written before its code (lead.md, contract rule 13): TL-10 landed it
// skipped, TL-12 turned it on. Lanes and keys are found by the identifiers the
// gallery opts into (`suite.timeline.lane.<id>`, `suite.timeline.key.<id>.<frame>`),
// and Badge's value by the hidden `suite.gallery.timeline.value.badge`'s label,
// since XCUITest reads SwiftUI values as "" (#262, #1800). Keys are clicked
// at their element's centre, not through the element (#1783).
import XCTest

extension SuiteJourneyTests {
    /// SJ19b: keys are picked by click, Shift, ⌘, right-click, the bed, ← → and VoiceOver.
    @MainActor func testTimelinePicksKeys() throws {
        try walkTimelinePicks()
    }

    @MainActor private func walkTimelinePicks() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline"])
        XCTAssert(gallery.element("suite.gallery.timeline").waitForExistence(timeout: 30), "no timeline page")
        let log = gallery.element("suite.gallery.log")
        XCTAssert(log.waitForExistence(timeout: 10), "no suite.gallery.log on the timeline page")

        // 1. Click Ball's key at 12: it replaces the pick and reads selected.
        let ball12 = timelineKey(12, lane: "ball", gallery)
        timelineSpot(ball12).click()
        expectTimelineLog("pick ball 12 replace", log)
        XCTAssert(timelineWait { ball12.isSelected }, "Ball's key at 12 isn't selected after its click")
        gallery.shot("timeline-picked")

        // 2. Shift-click Ball's key at 24, then ⌘-click 12.
        let ball24 = timelineKey(24, lane: "ball", gallery)
        XCUIElement.perform(withKeyModifiers: .shift) { self.timelineSpot(ball24).click() }
        expectTimelineLog("pick ball 24 extend", log)
        XCUIElement.perform(withKeyModifiers: .command) { self.timelineSpot(ball12).click() }
        expectTimelineLog("pick ball 12 toggle", log)

        // 3. Right-click Shadow's key at 36: it is picked and the menu offers Ease In.
        timelineSpot(timelineKey(36, lane: "shadow", gallery)).rightClick()
        expectTimelineLog("pick shadow 36 replace", log)
        XCTAssert(gallery.app.menuItems["Ease In"].waitForExistence(timeout: 5), "the key's context menu has no Ease In")
        gallery.shot("timeline-key-menu")
        gallery.press(.escape)
        XCTAssert(timelineWait { !gallery.app.menuItems["Ease In"].exists }, "the context menu stayed open after Escape")

        // 4. Click Ball's empty bed, halfway between its keys at 0 and 12: the pick clears.
        let ball0 = timelineKey(0, lane: "ball", gallery)
        let bedX = (ball0.frame.midX + ball12.frame.midX) / 2
        let lane = timelineLane("ball", gallery)
        lane.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: bedX - lane.frame.minX, dy: lane.frame.height / 2)).click()
        expectTimelineLog("pick ball none", log)

        // 5. Keyboard: Ball's key at 0, → twice picks 24; ← at the first key changes nothing.
        timelineSpot(ball0).click()
        expectTimelineLog("pick ball 0 replace", log)
        gallery.press(.rightArrow)
        gallery.press(.rightArrow)
        expectTimelineLog("pick ball 24 replace", log)
        timelineSpot(ball0).click()
        expectTimelineLog("pick ball 0 replace", log)
        let before = timelineText(log)
        gallery.press(.leftArrow)
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(timelineText(log), before, "← at Ball's first key changed the log")

        // 6. VoiceOver: Shadow's key at 36 by label and its default action; Badge's lane value.
        let shadow36 = timelineLane("shadow", gallery).descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Key at frame 36, eased")).firstMatch
        XCTAssert(shadow36.waitForExistence(timeout: 5), "no element \"Key at frame 36, eased\" on Shadow's lane")
        timelineSpot(shadow36).click()
        expectTimelineLog("pick shadow 36 replace", log)
        let badge = gallery.element("suite.gallery.timeline.value.badge")
        XCTAssert(badge.waitForExistence(timeout: 5), "no suite.gallery.timeline.value.badge")
        XCTAssertEqual(badge.label, "Frames 20–50, 3 keyframes at 20, 30, 50", "Badge's lane value")
        gallery.shot("timeline-keys-access")
    }

    /// The lane of track `id`, `suite.timeline.lane.<id>`.
    @MainActor private func timelineLane(_ id: String, _ gallery: Journey) -> XCUIElement {
        let lane = gallery.element("suite.timeline.lane.\(id)")
        XCTAssert(lane.waitForExistence(timeout: 5), "no lane suite.timeline.lane.\(id)")
        return lane
    }

    /// The key at `frame` on track `id`'s lane, `suite.timeline.key.<id>.<frame>`.
    @MainActor private func timelineKey(_ frame: Int, lane id: String, _ gallery: Journey) -> XCUIElement {
        let key = gallery.element("suite.timeline.key.\(id).\(frame)")
        XCTAssert(key.waitForExistence(timeout: 5), "no key suite.timeline.key.\(id).\(frame)")
        return key
    }

    /// The middle of a key's element. A key is a synthetic child, which
    /// XCUITest finds no hit point for and tries to scroll into view (it is
    /// in view already), so the pointer goes to its centre instead (#1783).
    @MainActor private func timelineSpot(_ key: XCUIElement) -> XCUICoordinate {
        key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    }

    /// The log's last line reads `line` within about three seconds.
    @MainActor private func expectTimelineLog(_ line: String, _ log: XCUIElement) {
        let last = { self.timelineText(log).split(separator: "\n").last.map(String.init) ?? "" }
        XCTAssert(timelineWait { last() == line }, "the log's last line reads \(last()), not \(line)")
    }

    /// What an element reads: its value when it has one, else its label.
    @MainActor private func timelineText(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }

    /// Whether `condition` holds within about three seconds.
    @MainActor private func timelineWait(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
