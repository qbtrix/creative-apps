// DesignJourneyTests+StressPerf.swift: Design's stress journey, the beta quality gate on a complex file. The
// bundled Design opens `stress` (DesignFixtures: 5,000 shapes loose on one 1440 x 1024 page) in a 1700 x 1000
// window and drives: Select All (⌘A), a drag of all 5,000 by shape 1, ⌘Z; from the empty corner a marquee over
// the dense top-left quarter (about 1,250 shapes), a drag of those by shape 1, ⌘Z; then a scroll-wheel pan at
// zoom and ⌘= / ⌘− steps. Design has no paths or Direct Select yet, so the 5,000-anchor case lives in Flare's
// stress journey; this one is thousands of layers. Page points map through `suite.canvas.artboard`, as
// DesignRealPerfJourneyTests does. Every gesture goes through Journey.health: step p95 where a series records
// (`canvas-drag`), main-thread surface allocation, the accessibility answer and idle CPU. Only `scripts/ui-test
// perf` runs it (perf-nightly at 04:30); Tests/render-budgets.md records what it measured.
import AppKit
import XCTest

final class DesignStressPerfJourneyTests: XCTestCase {
    @MainActor func testStress() {
        let design = Journey.realPerf("Design", self, arguments: ["-DesignFixture", "stress", "-SuiteWindowSize", "1700x1000", "-SuitePerfProbe"])
        let artboard = design.element("suite.canvas.artboard")
        guard artboard.waitForExistence(timeout: 120) else { return XCTFail("stress showed no page (suite.canvas.artboard)") }
        guard let pid = design.pid(of: "Design") else { return XCTFail("no running Design from .build/realperf (scripts/ui-test perf makes it)") }
        let page = (width: 1440.0, height: 1024.0)
        let at = { (x: Double, y: Double) in artboard.coordinate(withNormalizedOffset: CGVector(dx: x / page.width, dy: y / page.height)) }
        let points = { (length: Double) in artboard.frame.width * length / page.width }
        let shapeOne = (25.0, 17.0)  // the middle of Rectangle 1 at (20, 12)

        design.health("select-all", pid: pid, series: nil) { Journey.timed { design.press(character: "a", .command) } }
        design.health("drag-all", pid: pid, series: "canvas-drag") {
            Journey.drag(at(shapeOne.0, shapeOne.1), to: at(325, 167), distance: points(335))
            return []
        }
        design.health("undo-all", pid: pid, series: nil) { Journey.timed { design.press(character: "z", .command) } }

        design.press(.escape)
        design.health("marquee", pid: pid, series: "canvas-drag") {
            Journey.drag(at(5, 5), to: at(700, 500), distance: points(853))
            return []
        }
        design.health("drag-marquee", pid: pid, series: "canvas-drag") {
            Journey.drag(at(shapeOne.0, shapeOne.1), to: at(425, 317), distance: points(500))
            return []
        }
        design.health("undo-marquee", pid: pid, series: nil) { Journey.timed { design.press(character: "z", .command) } }

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
