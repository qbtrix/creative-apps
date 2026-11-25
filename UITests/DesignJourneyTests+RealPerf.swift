// DesignJourneyTests+RealPerf.swift: Design's real-app perf journey. The
// bundled Design opens `crowd` (2,000 layers, DesignFixtures) in a
// 1700 x 1000 window and drives, about 3 s each: the Move tool carrying
// Rectangle 1 of Frame 1 along the empty band under the first row of frames
// (page points through `suite.canvas.artboard`, as DesignPerfCanvasJourneyTests
// maps them), the same drag with Option held (a copy follows the pointer,
// the copy-group lift, held to the 16 ms hard line), the Opacity bar of
// Frame 36's Text, a scroll-wheel pan at zoom, and ⌘= / ⌘− zoom steps. Design has no View > Rendering switch, so it
// runs once. Every gesture goes through Journey.health (Journey+Health.swift):
// step p95, main-thread surface allocation, the accessibility answer and idle
// CPU. `testAnimated` opens `animated` (animated(500): 500 keyed rectangles, the live-doc hero's budget
// fixture, #6373) and drives, held to 8 ms: a sweep of the Frame Ruler (series `ruler-scrub`), then, at
// frame 60, the Move tool carrying the keyed Rectangle 1 where it shows there (`canvas-drag`), which keys it.
// Run by `scripts/ui-test perf` only, as Photo's real-perf journeys are.
import AppKit
import XCTest

final class DesignRealPerfJourneyTests: XCTestCase {
    @MainActor func testCrowd() {
        let design = Journey.realPerf("Design", self, arguments: ["-DesignFixture", "crowd", "-SuiteWindowSize", "1700x1000", "-SuitePerfProbe"])
        let artboard = design.element("suite.canvas.artboard")
        guard artboard.waitForExistence(timeout: 30) else { return XCTFail("crowd showed no page (suite.canvas.artboard)") }
        guard let pid = design.pid(of: "Design") else { return XCTFail("no running Design from .build/realperf (scripts/ui-test perf makes it)") }
        let page = (width: 1440.0, height: 1024.0)
        let at = { (x: Double, y: Double) in artboard.coordinate(withNormalizedOffset: CGVector(dx: x / page.width, dy: y / page.height)) }

        design.health("move", pid: pid, series: "canvas-drag") {
            let scale = NSScreen.main?.backingScaleFactor ?? 1, span = artboard.frame.width * 1360 / page.width
            at(20, 20).click(forDuration: 0.05, thenDragTo: at(1380, 185),
                             withVelocity: XCUIGestureVelocity(span * scale / 3), thenHoldForDuration: 0.05)
            return []
        }
        design.press(character: "z", .command)

        // The copy-group drag (#6198) holds the render contract's 16 ms hard line, not the 33 ms 8K
        // budget: its steady steps land on the next 120 Hz refresh (about 8 ms).
        design.health("option-move", pid: pid, series: "canvas-drag", budget: Health.realTimeBudget) {
            let scale = NSScreen.main?.backingScaleFactor ?? 1, span = artboard.frame.width * 1360 / page.width
            XCUIElement.perform(withKeyModifiers: .option) {
                at(20, 20).click(forDuration: 0.05, thenDragTo: at(1380, 185),
                                 withVelocity: XCUIGestureVelocity(span * scale / 3), thenHoldForDuration: 0.05)
            }
            return []
        }
        let undo = design.element("design.bar.undo")
        XCTAssert(undo.waitForExistence(timeout: 5) && undo.label == "Undo Duplicate",
                  "the Option-drag made no Duplicate step (Undo reads \(undo.label)), so it timed a plain drag")
        design.press(character: "z", .command)

        design.expandDesignLayer("design.layer.node-1751")
        design.clickDesignLayer("design.layer.node-1800")
        let opacity = design.element("suite.inspector").descendants(matching: .any)["design.inspector.opacity"].firstMatch
        if opacity.waitForExistence(timeout: 10) {
            design.health("opacity", pid: pid, series: "bar-slider") { design.scrub(opacity); return [] }
        } else {
            XCTFail("no design.inspector.opacity with Frame 36's Text selected")
        }

        let viewport = design.element("suite.viewport")
        for _ in 0..<3 { design.press(character: "=", .command) }
        design.health("pan", pid: pid, series: nil) {
            Journey.repeatFor(seconds: 3) { step in
                viewport.scroll(byDeltaX: step.isMultiple(of: 2) ? 80 : -80, deltaY: step.isMultiple(of: 4) ? 60 : -60)
            }
        }
        design.health("zoom", pid: pid, series: nil) {
            Journey.repeatFor(seconds: 3) { step in design.press(character: step.isMultiple(of: 2) ? "-" : "=", .command) }
        }
    }

    /// The live-doc hero's real-time box (#6373): scrub and keyed drag on animated(500), p95 at or under 8 ms.
    @MainActor func testAnimated() {
        let design = Journey.realPerf("Design", self, arguments: ["-DesignFixture", "animated", "-SuiteWindowSize", "1700x1000", "-SuitePerfProbe"])
        let artboard = design.element("suite.canvas.artboard")
        guard artboard.waitForExistence(timeout: 30) else { return XCTFail("animated showed no page (suite.canvas.artboard)") }
        guard let pid = design.pid(of: "Design") else { return XCTFail("no running Design from .build/realperf (scripts/ui-test perf makes it)") }
        let ruler = design.element("suite.timeline.ruler")
        guard ruler.waitForExistence(timeout: 10) else { return XCTFail("a keyed document showed no Frame Ruler") }
        let scale = NSScreen.main?.backingScaleFactor ?? 1, lastFrame = 299.0
        let tick = { (frame: Double) in
            ruler.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: 8 + frame * (ruler.frame.width - 24) / lastFrame, dy: ruler.frame.height / 2))
        }
        let frameShown = { Int((ruler.value as? String ?? "").split(separator: " ").last ?? "") ?? -1 }

        design.health("ruler-scrub", pid: pid, series: "ruler-scrub", budget: 8) {
            tick(0).press(forDuration: 0.05, thenDragTo: tick(lastFrame),
                          withVelocity: XCUIGestureVelocity(ruler.frame.width * scale / 3), thenHoldForDuration: 0.05)
            return []
        }
        XCTAssert(frameShown() > 250, "the ruler sweep left the playhead at frame \(frameShown())")

        tick(0).press(forDuration: 0.05, thenDragTo: tick(60))
        XCTAssert((58...62).contains(frameShown()), "the ruler drag to 60 read frame \(frameShown())")
        let page = (width: 1440.0, height: 1024.0)
        let at = { (x: Double, y: Double) in artboard.coordinate(withNormalizedOffset: CGVector(dx: x / page.width, dy: y / page.height)) }
        // Rectangle 1 (node-2) at frame 60 sits at 47, 40, 24 x 16 (DesignNodeTimeTests).
        design.health("keyed-move", pid: pid, series: "canvas-drag", budget: 8) {
            let span = artboard.frame.width * 600 / page.width
            at(59, 48).click(forDuration: 0.05, thenDragTo: at(659, 348),
                             withVelocity: XCUIGestureVelocity(span * scale / 3), thenHoldForDuration: 0.05)
            return []
        }
        let keyed = design.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH 'design.timeline.key.' AND identifier ENDSWITH '.60'")).firstMatch
        XCTAssert(keyed.waitForExistence(timeout: 5), "the drag at frame 60 keyed nothing there, so it timed no keyed move")
        design.press(character: "z", .command)
    }
}
