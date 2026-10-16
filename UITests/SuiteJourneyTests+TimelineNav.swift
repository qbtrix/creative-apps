// SuiteJourneyTests+TimelineNav.swift: SJ19d, the timeline strip's zoom,
// sideways scroll, frames/timecode switch and work area (timeline packet,
// Journey steps 7; TL-16 writes it skipped, TL-19 enables it). On
// `-SuiteGallery timeline-long` with the toolbar it drags the "Zoom" bar
// right (the ruler's labels change, the bar's value grows), clicks Fit (the
// value is back), clicks a lane and presses ⌘+ twice and ⌘− once (a step of
// its own; the value follows), scrolls sideways with the wheel (the ruler's
// labels change, the names column stays put), clicks "Timecode" (log
// `unit timecode`, the ruler reads 00:01:06 style), clicks "Frames" back,
// clicks "Work Area" (log `work 0…9999`), drags the work area's left handle
// 120 pt right and its right handle 200 pt left (one log line per drag end),
// and presses Escape mid-drag on the right handle (nothing logged). The ruler
// draws in a Canvas, so its accessibility value names its visible labels;
// the handles are `suite.gallery.timeline.work-start` and `.work-end` (TL-18).
import XCTest

extension SuiteJourneyTests {
    /// SJ19d: zoom by bar, Fit and keys, scroll sideways, switch units, set the work area.
    @MainActor func testTimelineZoomsScrollsAndSetsTheWorkArea() throws {
        throw XCTSkip("waits on TL-19")
        try walkTimelineNav()
    }

    @MainActor private func walkTimelineNav() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline-long"])
        let ruler = gallery.element("suite.timeline.ruler")
        XCTAssert(ruler.waitForExistence(timeout: 30), "timeline-long has no ruler (suite.timeline.ruler)")
        let zoom = gallery.app.descendants(matching: .any)["Zoom"].firstMatch
        XCTAssert(zoom.waitForExistence(timeout: 10), "the toolbar has no Zoom bar")
        let log = gallery.element("suite.gallery.log")
        gallery.shot("timeline-nav-idle")

        // 1. Drag the Zoom bar right: the ruler's labels change and the bar's value grows.
        let fitLabels = navText(ruler), fitZoom = navNumber(zoom)
        zoom.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: zoom.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        XCTAssertGreaterThan(navNumber(zoom), fitZoom, "dragging Zoom right didn't grow its value")
        XCTAssertNotEqual(navText(ruler), fitLabels, "zooming in left the ruler's labels as they were")
        gallery.shot("timeline-nav-zoomed")

        // 2. Fit: back to the whole range.
        gallery.app.buttons["Fit"].firstMatch.click()
        XCTAssert(navWait { self.navNumber(zoom) == fitZoom }, "Fit left the zoom at \(navNumber(zoom))")

        // 3. Keys, after a click on a lane: ⌘+ twice, ⌘− once; the value follows.
        ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 3)).click()
        gallery.app.typeKey("+", modifierFlags: .command)
        gallery.app.typeKey("+", modifierFlags: .command)
        let twice = navNumber(zoom)
        XCTAssertGreaterThan(twice, fitZoom, "⌘+ twice didn't zoom in")
        gallery.app.typeKey("-", modifierFlags: .command)
        XCTAssert(navWait { self.navNumber(zoom) < twice && self.navNumber(zoom) > fitZoom }, "⌘− didn't step back one stop")

        // 4. Scroll sideways with the wheel: the ruler's labels change, the names column stays.
        let names = gallery.app.staticTexts.firstMatch
        let namesX = names.frame.minX, before = navText(ruler)
        ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 3)).scroll(byDeltaX: -600, deltaY: 0)
        XCTAssert(navWait { self.navText(ruler) != before }, "a sideways scroll left the ruler's labels as they were")
        XCTAssertEqual(names.frame.minX, namesX, accuracy: 1, "the names column moved with the scroll")
        gallery.shot("timeline-nav-scrolled")

        // 5. Timecode, then Frames back.
        gallery.app.descendants(matching: .any)["Timecode"].firstMatch.click()
        XCTAssert(navWait { self.navText(log).contains("unit timecode") }, "Timecode logged \(navText(log))")
        XCTAssert(navText(ruler).range(of: #"\d\d:\d\d:\d\d"#, options: .regularExpression) != nil, "the ruler reads \(navText(ruler))")
        gallery.shot("timeline-nav-timecode")
        gallery.app.descendants(matching: .any)["Frames"].firstMatch.click()
        XCTAssert(navWait { self.navText(log).contains("unit frames") }, "Frames logged \(navText(log))")

        // 6. Work Area on, then drag each handle; one log line per drag end.
        gallery.app.descendants(matching: .any)["Work Area"].firstMatch.click()
        XCTAssert(navWait { self.navText(log).contains("work 0…9999") }, "Work Area logged \(navText(log))")
        let start = gallery.element("suite.gallery.timeline.work-start")
        let end = gallery.element("suite.gallery.timeline.work-end")
        XCTAssert(start.waitForExistence(timeout: 5) && end.exists, "no work area handles")
        let mid = CGVector(dx: 0.5, dy: 0.5)
        start.coordinate(withNormalizedOffset: mid)
            .press(forDuration: 0.1, thenDragTo: start.coordinate(withNormalizedOffset: mid).withOffset(CGVector(dx: 120, dy: 0)))
        XCTAssert(navWait { self.navWorkArea(self.navText(log)).map { $0.0 > 0 && $0.1 == 9999 } ?? false }, "left handle logged \(navText(log))")
        end.coordinate(withNormalizedOffset: mid)
            .press(forDuration: 0.1, thenDragTo: end.coordinate(withNormalizedOffset: mid).withOffset(CGVector(dx: -200, dy: 0)))
        XCTAssert(navWait { self.navWorkArea(self.navText(log)).map { $0.0 > 0 && $0.1 < 9999 } ?? false }, "right handle logged \(navText(log))")
        gallery.shot("timeline-nav-work-area")

        // 7. Escape mid-drag on the right handle: nothing logged. XCUITest
        // can't type during a synthesized drag, so this holds the handle and
        // presses Escape; TL-19 makes it a true mid-drag if TL-18's handle allows.
        let settled = navText(log)
        end.coordinate(withNormalizedOffset: mid).press(forDuration: 0.5)
        gallery.app.typeKey(.escape, modifierFlags: [])
        XCTAssertEqual(navText(log), settled, "Escape mid-drag logged a work area")
    }

    /// An element's value as text, else its label.
    @MainActor private func navText(_ element: XCUIElement) -> String {
        (element.value as? String) ?? element.label
    }

    /// The Zoom bar's value as a number ("2.5×" reads 2.5); 0 when it has none.
    @MainActor private func navNumber(_ element: XCUIElement) -> Double {
        if let n = element.value as? NSNumber { return n.doubleValue }
        let digits = navText(element).filter { $0.isNumber || $0 == "." }
        return Double(digits) ?? 0
    }

    /// The last `work <in>…<out>` in the log.
    private func navWorkArea(_ log: String) -> (Int, Int)? {
        guard let line = log.components(separatedBy: "\n").last(where: { $0.hasPrefix("work ") }) else { return nil }
        let parts = line.dropFirst(5).components(separatedBy: "…").compactMap { Int($0) }
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }

    @MainActor private func navWait(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
