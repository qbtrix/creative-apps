// FlareJourneyTests+RealPerf.swift: Flare's real-app perf journey. The
// bundled Flare opens `-FlareSample bounce` in a 1600 x 900 window (its timeline
// fits above the Dock) and
// drives, about 3 s each: a drag across the middle of the stage
// (`suite.canvas`, CanvasViewport), then with Ball selected from its timeline
// track the Rotation bar in the inspector (`flare.inspector.rotation`), a
// scroll-wheel pan at zoom, and
// ⌘= / ⌘− zoom steps. Flare has no View > Rendering switch, so it runs once.
// Every gesture goes through Journey.health (Journey+Health.swift): step p95,
// main-thread surface allocation, the accessibility answer and idle CPU. Run
// by `scripts/ui-test perf` only, as Photo's real-perf journeys are.
import AppKit
import XCTest

final class FlareRealPerfJourneyTests: XCTestCase {
    @MainActor func testBounce() {
        let flare = Journey.realPerf("Flare", self, arguments: ["-FlareSample", "bounce", "-SuiteWindowSize", "1600x900", "-SuitePerfProbe"])
        let stage = flare.element("suite.canvas")
        guard stage.waitForExistence(timeout: 30) else { return XCTFail("bounce showed no stage (suite.canvas)") }
        guard let pid = flare.pid(of: "Flare") else { return XCTFail("no running Flare from .build/realperf (scripts/ui-test perf makes it)") }

        flare.health("stage-drag", pid: pid, series: "canvas-drag") {
            let span = stage.frame.width * 0.3, scale = NSScreen.main?.backingScaleFactor ?? 1
            stage.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)).click(
                forDuration: 0.05, thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5)),
                withVelocity: XCUIGestureVelocity(span * scale / 3), thenHoldForDuration: 0.05)
            return []
        }

        let ball = flare.element("flare.timeline").buttons.matching(NSPredicate(format: "label == 'Ball'")).firstMatch
        if ball.waitForExistence(timeout: 10) { ball.click() } else { XCTFail("no Ball track in the timeline") }
        let rotation = flare.element("flare.inspector.rotation")
        if rotation.waitForExistence(timeout: 10) {
            flare.health("rotation", pid: pid, series: "bar-slider") { flare.scrub(rotation); return [] }
        } else {
            XCTFail("no flare.inspector.rotation with Ball selected")
        }

        let viewport = flare.element("suite.viewport").exists ? flare.element("suite.viewport") : stage
        for _ in 0..<3 { flare.press(character: "=", .command) }
        flare.health("pan", pid: pid, series: nil) {
            Journey.repeatFor(seconds: 3) { step in
                viewport.scroll(byDeltaX: step.isMultiple(of: 2) ? 80 : -80, deltaY: step.isMultiple(of: 4) ? 60 : -60)
            }
        }
        flare.health("zoom", pid: pid, series: nil) {
            Journey.repeatFor(seconds: 3) { step in flare.press(character: step.isMultiple(of: 2) ? "-" : "=", .command) }
        }
    }
}
