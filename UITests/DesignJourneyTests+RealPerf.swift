// DesignJourneyTests+RealPerf.swift: Design's real-app perf journey. The
// bundled Design opens `crowd` (2,000 layers, DesignFixtures) in a
// 1700 x 1000 window and drives, about 3 s each: the Move tool carrying
// Rectangle 1 of Frame 1 along the empty band under the first row of frames
// (page points through `suite.canvas.artboard`, as DesignPerfCanvasJourneyTests
// maps them), the Opacity bar of Frame 36's Text, a scroll-wheel pan at
// zoom, and ⌘= / ⌘− zoom steps. Design has no View > Rendering switch, so it
// runs once. Every gesture goes through Journey.health (Journey+Health.swift):
// step p95, main-thread surface allocation, the accessibility answer and idle
// CPU. Run by `scripts/ui-test perf` only, as Photo's real-perf journeys are.
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
}
