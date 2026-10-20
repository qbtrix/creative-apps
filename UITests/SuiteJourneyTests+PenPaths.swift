// SuiteJourneyTests+PenPaths.swift: PJ1, the gallery's `pen-paths` page, the packet's Journey steps 1 to 7
// (numbered below; docs/blueprints/suiteui/features/pen-paths.md). PN-2 writes it; it skips until PN-4 turns it
// on. Until PN-8 the page logs each intent instead of running it, so the log lines are intent command ids.
import XCTest

final class SuitePenPathsJourneyTests: XCTestCase {
    private static let penWait = true

    @MainActor func testPenDrawsAndEditsAPath() throws {
        if Self.penWait { throw XCTSkip("waits on PN-4") }
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
        first.click()
        expectPenLog(gallery, "path.close", count: 1)
        expectPenLog(gallery, "path.pen-add", count: 4)
        let sample = gallery.element("suite.path.anchors") // 5. Marquee two sample anchors, drag one 20 pt.
        XCTAssert(sample.waitForExistence(timeout: 5), "no suite.path.anchors")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.15))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.45)))
        expectPenLog(gallery, "path.anchor-select", count: 1)
        gallery.shot("pen-paths-selected")
        let anchor = gallery.element("suite.path.anchor-0-0")
        anchor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: anchor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 20, dy: 0)))
        expectPenLog(gallery, "path.anchor-move", count: 1, atLeast: true)
        let handle = gallery.element("suite.path.handle-0-1-out") // 6. A smooth handle turns its partner; Option breaks.
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 10, dy: 10)))
        expectPenLog(gallery, "path.handle-move", count: 1, atLeast: true)
        XCUIElement.perform(withKeyModifiers: .option) {
            handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: -10, dy: 0)))
        }
        expectPenLog(gallery, "breaking", count: 1, atLeast: true)
        gallery.press(character: "p")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.675, dy: 0.15)).click()
        expectPenLog(gallery, "path.anchor-insert", count: 1)
        gallery.press(.delete)
        expectPenLog(gallery, "path.anchor-remove", count: 1)
        gallery.press(.rightArrow) // 7. Keyboard: nudge, Shift-nudge, Return, Escape, VoiceOver's anchor label.
        gallery.press(.rightArrow, .shift)
        XCTAssert(gallery.penLog.contains("dx: 1.0") && gallery.penLog.contains("dx: 10.0"), "the arrows didn't nudge 1 and 10 pt")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.85)).click()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.85)).click()
        gallery.press(.return)
        expectPenLog(gallery, "path.finish", count: 1)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.95)).click()
        gallery.press(.escape)
        expectPenLog(gallery, "path.cancel", count: 1)
        let label = gallery.element("suite.path.anchor-0-1").label
        XCTAssert(label.hasPrefix("Anchor 2 of "), "VoiceOver reads \(label), not Anchor 2 of n")
        gallery.shot("pen-paths-keyboard")
    }

    /// Waits up to five seconds for the page's log to hold `text` `count` times (or more, when `atLeast`).
    @MainActor private func expectPenLog(_ gallery: Journey, _ text: String, count: Int, atLeast: Bool = false) {
        var seen = 0
        for _ in 0..<10 {
            seen = gallery.penLog.components(separatedBy: "\n").filter { $0.contains(text) }.count
            if seen == count || (atLeast && seen >= count) { return }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("the log holds \(seen) \(text), not \(count); it reads \(gallery.penLog)")
    }
}

extension Journey {
    /// The gallery page's `suite.gallery.log` value; empty when the page has none.
    @MainActor fileprivate var penLog: String { element("suite.gallery.log").value as? String ?? "" }
}
