// SuiteJourneyTests+PenPaths.swift: PJ1, the gallery's `pen-paths` page, the packet's Journey steps 1 to 7
// (numbered below; docs/blueprints/suiteui/features/pen-paths.md). PN-2 wrote it; PN-4 turns it on. Until PN-8
// the page logs each intent instead of running it, so the log lines are intent command ids. Two flags hold the
// checks that need later slices: `penRulesWait` (PN-5: until PenRules keeps the Pen's anchors there is no
// close ring and no close, so step 4 drops the draft with Escape instead) and `pageWait` (PN-8: until the page
// keeps a selection, handles take no hits and Delete and the arrows have nothing to act on). Every other
// check runs; the test then skips, naming what waits, so a skip never hides a failure recorded before it.
import XCTest

final class SuitePenPathsJourneyTests: XCTestCase {
    private static let penRulesWait = true
    private static let pageWait = true

    @MainActor func testPenDrawsAndEditsAPath() throws {
        var waiting: [String] = []
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.element("suite.gallery.index.pen-paths").click() // 1. An empty canvas, the Pen chosen, a sample path.
        XCTAssert(gallery.element("suite.gallery.pen-paths").waitForExistence(timeout: 10), "no suite.gallery.pen-paths")
        let canvas = gallery.element("suite.gallery.pen-canvas")
        XCTAssert(canvas.exists, "no suite.gallery.pen-canvas")
        gallery.shot("pen-paths-open")
        for spot in [CGVector(dx: 0.1, dy: 0.2), CGVector(dx: 0.3, dy: 0.2), CGVector(dx: 0.3, dy: 0.5)] { // 2. Three corners.
            canvas.coordinate(withNormalizedOffset: spot).click()
        }
        expectPenLog(gallery, "path.pen-add", count: 3)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.6)).hover()
        gallery.shot("pen-paths-drawing")
        let fourth = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.6)) // 3. A smooth anchor.
        fourth.press(forDuration: 0.2, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7)))
        expectPenLog(gallery, "path.pen-add", count: 4)
        gallery.shot("pen-paths-smooth")
        let first = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.2)) // 4. Close on the first anchor.
        first.hover()
        gallery.shot("pen-paths-close-hover")
        if Self.penRulesWait {
            waiting.append("step 4 close ring and close (PN-5)")
            gallery.press(.escape)
            expectPenLog(gallery, "path.cancel", count: 1)
        } else {
            XCTAssert(gallery.element("suite.path.close-ring").waitForExistence(timeout: 5), "no close ring on the first anchor")
            first.click()
            expectPenLog(gallery, "path.close", count: 1)
            expectPenLog(gallery, "path.pen-add", count: 4)
        }
        choose(gallery, tool: "Direct Selection") // 5. Marquee two sample anchors, drag one 20 pt.
        let sample = gallery.element("suite.path.anchors")
        XCTAssert(sample.waitForExistence(timeout: 5), "no suite.path.anchors")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.15))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.45)))
        expectPenLog(gallery, "path.anchor-select", count: 1)
        XCTAssert(gallery.penLog.contains("rect:"), "the marquee sent no rect: \(gallery.penLog)")
        gallery.shot("pen-paths-selected")
        let anchor = gallery.element("suite.path.anchor-0-0")
        XCTAssert(anchor.waitForExistence(timeout: 5), "no suite.path.anchor-0-0")
        anchor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: anchor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 20, dy: 0)))
        expectPenLog(gallery, "path.anchor-move", count: 1, atLeast: true)
        let handle = gallery.element("suite.path.handle-0-1-out") // 6. A smooth handle turns its partner; Option breaks.
        XCTAssert(handle.waitForExistence(timeout: 5), "no suite.path.handle-0-1-out")
        if Self.pageWait {
            waiting.append("step 6 handle drag, Option break and Delete (PN-8)")
        } else {
            handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 10, dy: 10)))
            expectPenLog(gallery, "path.handle-move", count: 1, atLeast: true)
            XCUIElement.perform(withKeyModifiers: .option) {
                handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    .press(forDuration: 0.1, thenDragTo: handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: -10, dy: 0)))
            }
            expectPenLog(gallery, "breaking: true", count: 1, atLeast: true)
        }
        choose(gallery, tool: "Pen")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7273, dy: 0.7708)).click() // Segment 2→3's midpoint, which steps 5 and 6 leave.
        expectPenLog(gallery, "path.anchor-insert", count: 1)
        if !Self.pageWait {
            gallery.press(.delete)
            expectPenLog(gallery, "path.anchor-remove", count: 1)
            gallery.press(.rightArrow) // 7. Keyboard: nudge, Shift-nudge, Return, Escape, VoiceOver's anchor label.
            gallery.press(.rightArrow, .shift)
            XCTAssert(gallery.penLog.contains("dx: 1.0") && gallery.penLog.contains("dx: 10.0"), "the arrows didn't nudge 1 and 10 pt")
        } else {
            waiting.append("step 7 arrow nudges (PN-8)")
        }
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.85)).click()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.85)).click()
        gallery.press(.return)
        expectPenLog(gallery, "path.finish", count: 1)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.95)).click()
        gallery.press(.escape)
        expectPenLog(gallery, "path.cancel", count: Self.penRulesWait ? 2 : 1)
        let label = gallery.element("suite.path.anchor-0-1").label
        XCTAssert(label.hasPrefix("Anchor 2 of "), "VoiceOver reads \(label), not Anchor 2 of n")
        gallery.shot("pen-paths-keyboard")
        if !waiting.isEmpty { throw XCTSkip("waits on " + waiting.joined(separator: "; ")) }
    }

    /// Clicks the `title` segment of the page's tool picker.
    @MainActor private func choose(_ gallery: Journey, tool title: String) {
        var segment = gallery.element("suite.gallery.pen-tool").radioButtons[title].firstMatch
        if !segment.waitForExistence(timeout: 5) { segment = gallery.app.radioButtons[title].firstMatch }
        XCTAssert(segment.waitForExistence(timeout: 5), "no \(title) segment in suite.gallery.pen-tool")
        segment.click()
    }

    /// Waits up to five seconds for the page's log to hold `text` `count` times (or more, when `atLeast`); a line
    /// the commands refused doesn't count.
    @MainActor private func expectPenLog(_ gallery: Journey, _ text: String, count: Int, atLeast: Bool = false) {
        var seen = 0
        for _ in 0..<10 {
            seen = gallery.penLog.components(separatedBy: "\n").filter { $0.contains(text) && !$0.contains("[refused") }.count
            if seen == count || (atLeast && seen >= count) { return }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("the log holds \(seen) \(text), not \(count); it reads \(gallery.penLog)")
    }
}

extension Journey {
    /// The gallery page's `suite.gallery.log` lines: its value, or its label where XCUITest reads the value as
    /// empty (#262); empty when the page has none.
    @MainActor fileprivate var penLog: String {
        let log = element("suite.gallery.log")
        let value = log.value as? String ?? ""
        return value.isEmpty ? log.label : value
    }
}
