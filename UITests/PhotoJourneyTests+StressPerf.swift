// PhotoJourneyTests+StressPerf.swift: Photo's stress journey, the beta quality gate on a complex file. The
// real-perf copy of Photo opens `-PhotoFixture stress` (PhotoFixtures: 3840 x 2160 in 100 layers, a quarter of
// them adjustment layers and a quarter masked) with View > Rendering on the GPU (`-suite.rendering gpu`, before
// the bare -SuitePerfProbe as PhotoRealPerfJourneyTests explains) in a 1700 x 1000 window, and drives: Select
// Layer Below (⌥⌘[) for about 3 s, stepping down the stack; the top layer's row clicked, then the Move tool across
// the canvas, ⌘Z; every eye on screen in the Layers list clicked twice (hidden, then shown) for about 3 s; and
// the Levels Black slider dragged with every layer visible, ⌘Z. Photo selects one layer at a time, so "select
// many layers" is stepping through them. The fixture runs on the fake file services (a "Preview data" pill) and
// the real renderer. Every gesture goes through Journey.health: step p95 where a series records (`canvas-drag`,
// `bar-slider`), main-thread surface allocation, the accessibility answer and idle CPU. Only `scripts/ui-test
// perf` runs it (perf-nightly at 04:30); Tests/render-budgets.md records what it measured.
import AppKit
import XCTest

final class PhotoStressPerfJourneyTests: XCTestCase {
    @MainActor func testStress() {
        let arguments = photoArguments(fixture: "stress", recoveryDir: Health.out.appending(path: "recovery-stress"), windowSize: "1700x1000")
            + ["-suite.rendering", "gpu", "-SuitePerfProbe"]
        let photo = Journey.realPerf("Photo", self, arguments: arguments)
        let header = photo.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "3840 × 2160 px")).firstMatch
        guard header.waitForExistence(timeout: 120) else { return XCTFail("the stress document didn't open (no 3840 × 2160 px)") }
        guard let pid = photo.pid(of: "Photo") else { return XCTFail("no running Photo from .build/realperf (scripts/ui-test perf makes it)") }
        let layers = photo.element("suite.sidebar").descendants(matching: .any)["photo.layers"]
        guard layers.waitForExistence(timeout: 10) else { return XCTFail("the sidebar shows no layer list (photo.layers)") }

        photo.health("select-layers", pid: pid, series: nil) {
            Journey.repeatFor(seconds: 3) { _ in photo.press(character: "[", [.command, .option]) }
        }

        let top = layers.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'photo.layer.row.'")).firstMatch
        if top.waitForExistence(timeout: 5) { top.click() } else { XCTFail("no layer row (photo.layer.row.*)") }
        let viewport = photo.element("suite.viewport")
        photo.element("suite.tools").buttons["Move"].click()
        photo.health("move", pid: pid, series: "canvas-drag") {
            Journey.drag(viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)),
                         to: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)), distance: viewport.frame.width * 0.4)
            return []
        }
        photo.press(character: "z", .command)

        let eyes = layers.descendants(matching: .any).matching(NSPredicate(format: "identifier ENDSWITH '.eye'"))
            .allElementsBoundByIndex.filter(\.isHittable)
        if eyes.isEmpty {
            XCTFail("no eye on screen in the Layers list (photo.layer.<id>.eye)")
        } else {
            print("realperf photo stress: \(eyes.count) eyes on screen")
            var clicks = 0
            photo.health("toggle-visibility", pid: pid, series: nil) {
                let times = Journey.repeatFor(seconds: 3) { step in eyes[(step / 2) % eyes.count].click() }
                clicks = times.count
                return times
            }
            // An odd number of clicks leaves the last eye's layer hidden: show it before Levels.
            if !clicks.isMultiple(of: 2) { eyes[(clicks / 2) % eyes.count].click() }
        }

        let black = photo.app.sliders["Black"]
        if black.waitForExistence(timeout: 10) {
            photo.reveal(black)
            photo.health("levels", pid: pid, series: "bar-slider") { photo.scrub(black); return [] }
            photo.press(character: "z", .command)
        } else {
            XCTFail("no Levels Black slider with the top layer selected")
        }
    }
}
