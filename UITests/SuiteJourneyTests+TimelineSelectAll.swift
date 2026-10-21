// SuiteJourneyTests+TimelineSelectAll.swift: SJ19f, TSA-a (packet
// docs/blueprints/suiteui/features/timeline-select-all.md, Journey steps 1 to
// 4). On the `timeline` gallery page a click on Ball's empty bed gives the
// strip focus (log `pick ball none`); ⌘A then logs `select-all` and every key
// on every lane reads selected. With the pick cleared again, the page's Select
// All Keys button (`gallery.timeline.selectAll`) does the same with the mouse
// alone, and a bed click clears the pick. The gallery runs in Halo, which
// keeps the system Select All item, so ⌘A reaches the strip as the responder
// chain's selectAll: (Library's gallery host has its own Select All, disabled
// with no photos, which would take the key first). Keys are clicked at their
// element's centre (#1783), as SuiteJourneyTests+TimelineKeys does.
import XCTest

extension SuiteJourneyTests {
    /// SJ19f: ⌘A on the focused strip and the Select All Keys button pick every key.
    @MainActor func testTimelineSelectsAllKeys() throws {
        let gallery = Journey("Halo", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline"])
        XCTAssert(gallery.element("suite.gallery.timeline").waitForExistence(timeout: 30), "no timeline page")
        let log = gallery.element("suite.gallery.log")
        XCTAssert(log.waitForExistence(timeout: 10), "no suite.gallery.log on the timeline page")

        // 1. Click Ball's empty bed, halfway between its keys at 0 and 12: the strip takes focus.
        clickSelectAllBed(gallery)
        expectSelectAllLog("pick ball none", log)
        XCTAssert(selectAllWait { self.pickedKeys(gallery).isEmpty }, "a key stayed picked after the bed click")

        // 2. ⌘A: the log reads select-all and every key on every lane is picked.
        gallery.press(character: "a", .command, step: "select all keys")
        expectSelectAllLog("select-all", log)
        XCTAssert(selectAllWait { self.pickedKeys(gallery).count == Self.allKeys.count },
                  "⌘A picked \(pickedKeys(gallery)), not every key")
        gallery.shot("timeline-all-picked")

        // 3. Clear the pick, then the Select All Keys button does what ⌘A did.
        clickSelectAllBed(gallery)
        expectSelectAllLog("pick ball none", log)
        let button = gallery.element("gallery.timeline.selectAll")
        XCTAssert(button.waitForExistence(timeout: 5), "no gallery.timeline.selectAll button")
        button.click()
        expectSelectAllLog("select-all", log)
        XCTAssert(selectAllWait { self.pickedKeys(gallery).count == Self.allKeys.count },
                  "the button picked \(pickedKeys(gallery)), not every key")

        // 4. A click on an empty bed clears the pick (TL-c, unchanged).
        clickSelectAllBed(gallery)
        expectSelectAllLog("pick ball none", log)
        XCTAssert(selectAllWait { self.pickedKeys(gallery).isEmpty }, "keys stayed picked after the bed click")
    }

    /// Every key on the `timeline` page, as `<track>.<frame>`.
    private static let allKeys = [
        "ball.0", "ball.12", "ball.24", "ball.36", "shadow.12", "shadow.36", "badge.20", "badge.30", "badge.50",
    ]

    /// The keys whose elements read selected.
    @MainActor private func pickedKeys(_ gallery: Journey) -> [String] {
        Self.allKeys.filter { gallery.element("suite.timeline.key.\($0)").isSelected }
    }

    /// Clicks Ball's empty bed, halfway between its keys at 0 and 12.
    @MainActor private func clickSelectAllBed(_ gallery: Journey) {
        let lane = gallery.element("suite.timeline.lane.ball")
        let first = gallery.element("suite.timeline.key.ball.0")
        let second = gallery.element("suite.timeline.key.ball.12")
        XCTAssert(lane.waitForExistence(timeout: 5), "no lane suite.timeline.lane.ball")
        XCTAssert(first.waitForExistence(timeout: 5) && second.waitForExistence(timeout: 5), "no keys on Ball's lane")
        let bedX = (first.frame.midX + second.frame.midX) / 2
        lane.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: bedX - lane.frame.minX, dy: lane.frame.height / 2)).click()
    }

    /// The log's last line reads `line` within about three seconds.
    @MainActor private func expectSelectAllLog(_ line: String, _ log: XCUIElement) {
        let last = { () -> String in
            let value = log.value as? String ?? ""
            let text = value.isEmpty ? log.label : value
            return text.split(separator: "\n").last.map(String.init) ?? ""
        }
        XCTAssert(selectAllWait { last() == line }, "the log's last line reads \(last()), not \(line)")
    }

    /// Whether `condition` holds within about three seconds.
    @MainActor private func selectAllWait(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
