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
// skipped, TL-12 turned it on. A lane is found by its track name as label and
// a value that counts keyframes; a key by "Key at frame <n>" inside it.
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
        let ball12 = timelineKey(12, lane: "Ball", gallery)
        ball12.click()
        expectTimelineLog("pick ball 12 replace", log)
        XCTAssert(timelineWait { ball12.isSelected }, "Ball's key at 12 isn't selected after its click")
        gallery.shot("timeline-picked")

        // 2. Shift-click Ball's key at 24, then ⌘-click 12.
        let ball24 = timelineKey(24, lane: "Ball", gallery)
        XCUIElement.perform(withKeyModifiers: .shift) { ball24.click() }
        expectTimelineLog("pick ball 24 extend", log)
        XCUIElement.perform(withKeyModifiers: .command) { ball12.click() }
        expectTimelineLog("pick ball 12 toggle", log)

        // 3. Right-click Shadow's key at 36: it is picked and the menu offers Ease In.
        timelineKey(36, lane: "Shadow", gallery).rightClick()
        expectTimelineLog("pick shadow 36 replace", log)
        XCTAssert(gallery.app.menuItems["Ease In"].waitForExistence(timeout: 5), "the key's context menu has no Ease In")
        gallery.shot("timeline-key-menu")
        gallery.press(.escape)
        XCTAssert(timelineWait { !gallery.app.menuItems["Ease In"].exists }, "the context menu stayed open after Escape")

        // 4. Click Ball's empty bed, halfway between its keys at 0 and 12: the pick clears.
        let ball0 = timelineKey(0, lane: "Ball", gallery)
        let bedX = (ball0.frame.midX + ball12.frame.midX) / 2
        let lane = timelineLane("Ball", gallery)
        lane.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: bedX - lane.frame.minX, dy: lane.frame.height / 2)).click()
        expectTimelineLog("pick ball none", log)

        // 5. Keyboard: Ball's key at 0, → twice picks 24; ← at the first key changes nothing.
        ball0.click()
        expectTimelineLog("pick ball 0 replace", log)
        gallery.press(.rightArrow)
        gallery.press(.rightArrow)
        expectTimelineLog("pick ball 24 replace", log)
        ball0.click()
        expectTimelineLog("pick ball 0 replace", log)
        let before = timelineText(log)
        gallery.press(.leftArrow)
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(timelineText(log), before, "← at Ball's first key changed the log")

        // 6. VoiceOver: Shadow's key at 36 by label and its default action; Badge's lane value.
        let shadow36 = timelineLane("Shadow", gallery).descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Key at frame 36, eased")).firstMatch
        XCTAssert(shadow36.waitForExistence(timeout: 5), "no element \"Key at frame 36, eased\" on Shadow's lane")
        shadow36.click()
        expectTimelineLog("pick shadow 36 replace", log)
        let badge = timelineLane("Badge", gallery)
        XCTAssertEqual(badge.value as? String, "Frames 20–50, 3 keyframes at 20, 30, 50", "Badge's lane value")
        gallery.shot("timeline-keys-access")
    }

    /// The lane of track `name`: its label is the name and its value counts keyframes.
    @MainActor private func timelineLane(_ name: String, _ gallery: Journey) -> XCUIElement {
        let lane = gallery.app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ AND value CONTAINS 'keyframe'", name)).firstMatch
        XCTAssert(lane.waitForExistence(timeout: 5), "no lane for \(name)")
        return lane
    }

    /// The key at `frame` on `name`'s lane ("Key at frame <n>, <shape>").
    @MainActor private func timelineKey(_ frame: Int, lane name: String, _ gallery: Journey) -> XCUIElement {
        let key = timelineLane(name, gallery).descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Key at frame \(frame),")).firstMatch
        XCTAssert(key.waitForExistence(timeout: 5), "no key at \(frame) on \(name)'s lane")
        return key
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
