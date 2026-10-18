// SuiteJourneyTests+TimelineNav.swift: SJ19d, the timeline strip's zoom,
// sideways scroll, frames/timecode switch and work area (timeline packet,
// Journey steps 7; TL-16 wrote it skipped, TL-19 enables it). On
// `-SuiteGallery timeline-long` with the toolbar it drags the "Zoom" bar
// right (the ruler redraws, the bar's value grows), clicks Fit (the value is
// back), clicks a lane and presses ⌘+ twice and ⌘− once (a step of its own;
// the value follows; the host's own ⌘+ menu item must not take them, #2142), scrolls sideways with the wheel (the ruler redraws, the
// names column stays put), clicks "Timecode" (log `unit timecode`, the pill
// reads 00:05:00 style), clicks "Frames" back, clicks "Work Area" (log
// `work 0…9999`), drags the work area's left handle 120 pt right and its
// right handle 200 pt left (one log line per drag end), and presses Escape
// on the right handle (nothing logged). The ruler draws its labels in a
// Canvas and speaks only the playhead ("Frame 120"), so "the labels change"
// reads as the ruler's pixels changing. The work-area bar is hidden from
// accessibility, so its handles are found from a ruler click: the frame it
// scrubs to says where every frame sits (2 pt a frame at fit), and the wheel
// brings frame 0 or 9,999 into view first.
import XCTest

extension SuiteJourneyTests {
    /// SJ19d: zoom by bar, Fit and keys, scroll sideways, switch units, set the work area.
    @MainActor func testTimelineZoomsScrollsAndSetsTheWorkArea() throws {
        try walkTimelineNav()
    }

    @MainActor private func walkTimelineNav() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "timeline-long"])
        let ruler = gallery.element("suite.timeline.ruler")
        XCTAssert(ruler.waitForExistence(timeout: 30), "timeline-long has no ruler (suite.timeline.ruler)")
        let zoom = gallery.app.sliders["Zoom"].firstMatch
        XCTAssert(zoom.waitForExistence(timeout: 10), "the toolbar has no Zoom bar")
        let log = gallery.element("suite.gallery.log")
        gallery.shot("timeline-nav-idle")

        // 1. Drag the Zoom bar right: the ruler redraws and the bar's value grows.
        let fitRuler = navPixels(ruler), fitZoom = navNumber(zoom)
        zoom.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: zoom.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        XCTAssert(navWait { self.navNumber(zoom) > fitZoom }, "dragging Zoom right left it at \(navNumber(zoom))")
        XCTAssert(navWait { self.navPixels(ruler) != fitRuler }, "zooming in left the ruler as it was")
        gallery.shot("timeline-nav-zoomed")

        // 2. Fit: back to the whole range.
        gallery.app.buttons["Fit"].firstMatch.click()
        XCTAssert(navWait { self.navNumber(zoom) == fitZoom }, "Fit left the zoom at \(navNumber(zoom))")

        // 3. Keys, after a click on a lane: ⌘+ twice, ⌘− once; the value follows.
        ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 3)).click()
        gallery.app.typeKey("+", modifierFlags: .command)
        gallery.app.typeKey("+", modifierFlags: .command)
        XCTAssert(navWait { self.navNumber(zoom) > fitZoom }, "⌘+ twice didn't zoom in")
        let twice = navNumber(zoom)
        gallery.shot("timeline-nav-keys")
        gallery.app.typeKey("-", modifierFlags: .command)
        XCTAssert(navWait { self.navNumber(zoom) < twice && self.navNumber(zoom) > fitZoom }, "⌘− didn't step back one stop")

        // 4. Scroll sideways with the wheel: the ruler redraws, the names column stays.
        let names = gallery.app.buttons["Lane 1"].firstMatch
        XCTAssert(names.exists, "the names column has no Lane 1")
        let namesX = names.frame.minX, before = navPixels(ruler)
        ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 3)).scroll(byDeltaX: -600, deltaY: 0)
        if !navWait({ self.navPixels(ruler) != before }) {
            // Which way a wheel delta goes is the runner's setting; at an edge, the other way.
            ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 3)).scroll(byDeltaX: 600, deltaY: 0)
        }
        XCTAssert(navWait { self.navPixels(ruler) != before }, "a sideways scroll left the ruler as it was")
        XCTAssertEqual(names.frame.minX, namesX, accuracy: 1, "the names column moved with the scroll")
        gallery.shot("timeline-nav-scrolled")

        // 5. Timecode (a ruler click first brings the playhead and its pill into view), then Frames back.
        ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        let inFrames = navPixels(ruler)
        gallery.app.descendants(matching: .any)["Timecode"].firstMatch.click()
        XCTAssert(navWait { self.navText(log).contains("unit timecode") }, "Timecode logged \(navText(log))")
        XCTAssert(navWait { self.navPixels(ruler) != inFrames }, "Timecode left the ruler's labels as they were")
        // A macOS text reads in its value and leaves its label empty, so both are asked.
        let timecode = #"\d\d:\d\d:\d\d"#
        let pill = gallery.app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@ OR value MATCHES %@", timecode, timecode)).firstMatch
        XCTAssert(pill.waitForExistence(timeout: 5), "the playhead's pill doesn't read 00:05:00 style")
        gallery.shot("timeline-nav-timecode")
        gallery.app.descendants(matching: .any)["Frames"].firstMatch.click()
        XCTAssert(navWait { self.navText(log).contains("unit frames") }, "Frames logged \(navText(log))")

        // 6. Fit, Work Area on, then drag each handle; one log line per drag end.
        gallery.app.buttons["Fit"].firstMatch.click()
        XCTAssert(navWait { self.navNumber(zoom) == fitZoom }, "Fit left the zoom at \(navNumber(zoom))")
        gallery.app.descendants(matching: .any)["Work Area"].firstMatch.click()
        XCTAssert(navWait { self.navText(log).contains("work 0…9999") }, "Work Area logged \(navText(log))")
        let startX = try XCTUnwrap(navReveal(0, ruler: ruler), "frame 0 never came into view")
        navDragHandle(ruler, atX: startX, by: 120)
        XCTAssert(navWait { self.navWorkArea(self.navText(log)).map { $0.0 > 0 && $0.1 == 9999 } ?? false }, "left handle logged \(navText(log))")
        let endX = try XCTUnwrap(navReveal(9999, ruler: ruler), "frame 9999 never came into view")
        navDragHandle(ruler, atX: endX, by: -200)
        XCTAssert(navWait { self.navWorkArea(self.navText(log)).map { $0.0 > 0 && $0.1 < 9999 } ?? false }, "right handle logged \(navText(log))")
        gallery.shot("timeline-nav-work-area")

        // 7. Escape on the right handle: nothing logged. XCUITest can't type
        // during a synthesized drag, so this holds the handle and presses
        // Escape; TimelineRulerUnitTests covers Escape mid-drag itself.
        let out = try XCTUnwrap(navWorkArea(navText(log))?.1, "no work area in the log")
        let heldX = try XCTUnwrap(navReveal(out, ruler: ruler), "the right handle never came into view")
        let quiet = navText(log)
        navHandle(ruler, atX: heldX).press(forDuration: 0.5)
        gallery.app.typeKey(.escape, modifierFlags: [])
        XCTAssertEqual(navText(log), quiet, "Escape on the handle logged a work area")
    }

    /// Fit is 2 pt a frame (timeline-long's frameWidth).
    private static let navFrameWidth: CGFloat = 2

    /// The ruler's pixels: its labels draw in a Canvas.
    @MainActor private func navPixels(_ ruler: XCUIElement) -> Data {
        ruler.screenshot().pngRepresentation
    }

    /// Clicks the ruler's middle and reads the frame it scrubbed to from the
    /// ruler's value ("Frame 4060"); the x is in the ruler's own points.
    @MainActor private func navProbe(_ ruler: XCUIElement) -> (x: CGFloat, frame: Int)? {
        let old = navText(ruler)
        ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        // An unchanged value means the click landed on the playhead's frame already.
        _ = navWait { self.navText(ruler) != old }
        guard let frame = Int(navText(ruler).filter(\.isNumber)) else { return nil }
        return (ruler.frame.width / 2, frame)
    }

    /// Wheels the lanes until `frame` is in view at fit and returns its x in
    /// the ruler; which way a wheel delta goes is the runner's setting, so a
    /// scroll that left it no nearer flips the direction.
    @MainActor private func navReveal(_ frame: Int, ruler: XCUIElement) -> CGFloat? {
        var sign: CGFloat = 1
        var last: CGFloat?
        for _ in 0..<16 {
            guard let probe = navProbe(ruler) else { return nil }
            let x = probe.x + CGFloat(frame - probe.frame) * Self.navFrameWidth
            let low: CGFloat = 12, high = ruler.frame.width - 12
            if x >= low && x <= high { return x }
            let away = x < low ? low - x : x - high
            if let last, away >= last { sign = -sign }
            last = away
            let toward: CGFloat = x < low ? 1 : -1
            ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 3))
                .scroll(byDeltaX: sign * toward * min(away + 100, 4_000), deltaY: 0)
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return nil
    }

    /// A work-area handle at ruler x `x`: the 16 pt grip on the ruler's lower edge.
    @MainActor private func navHandle(_ ruler: XCUIElement, atX x: CGFloat) -> XCUICoordinate {
        ruler.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: ruler.frame.height - 8))
    }

    @MainActor private func navDragHandle(_ ruler: XCUIElement, atX x: CGFloat, by dx: CGFloat) {
        let handle = navHandle(ruler, atX: x)
        handle.press(forDuration: 0.1, thenDragTo: handle.withOffset(CGVector(dx: dx, dy: 0)))
    }

    /// An element's value as text, else its label.
    @MainActor private func navText(_ element: XCUIElement) -> String {
        (element.value as? String) ?? element.label
    }

    /// The Zoom bar's value as a number ("2.50" reads 2.5); 0 when it has none.
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
