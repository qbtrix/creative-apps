// HaloJourneyTests+RealPerf.swift: Halo's real-app perf journey. The bundled
// Halo opens `huge` (2,000 layers, every property keyed, HaloFixtures) in a
// 1700 x 1000 window and drags the layer under the artboard's middle for
// about 3 s in the viewer, through Journey.health (Journey+Health.swift):
// the `viewer-drag` steps, the accessibility answer, main-thread surface
// allocation and idle CPU, with scripts/realperf-watch sampling the real
// Halo helper process during the drag (its report stays in
// .build/realperf/<id>.sample.txt). Halo holds the drag to the render
// contract's real-time rule as well: step p95 at or under 16 ms (rule 6's
// hard limit) on top of Health's 33 ms. It runs only under
// `scripts/ui-test perf` (the real-perf copy in .build/realperf); without a
// copy made in the last three hours it skips, so a plain journeys run never
// waits on the watcher. Not yet in scripts/ui-test's `realperf` list, so run it
// as `scripts/ui-test perf -only-testing:HaloJourneyTests/HaloRealPerfJourneyTests`
// with `-skip-testing:` for the other three classes.
import AppKit
import XCTest

final class HaloRealPerfJourneyTests: XCTestCase {
    @MainActor func testHugeViewerDrag() throws {
        let made = (try? Health.out.appending(path: "AfterGlow.app").resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        try XCTSkipUnless(made.map { -$0.timeIntervalSinceNow < 3 * 3600 } ?? false, "no fresh real-perf copy (scripts/ui-test perf makes it)")
        let halo = Journey.realPerf("Halo", self, arguments: ["-HaloSample", "huge", "-HaloWindowSize", "1700x1000", "-SuitePerfProbe"])
        let canvas = halo.element("halo.viewer.canvas")
        guard canvas.waitForExistence(timeout: 60) else { return XCTFail("huge showed no artboard (halo.viewer.canvas)") }
        guard let pid = halo.pid(of: "Halo") else { return XCTFail("no running Halo from .build/realperf (scripts/ui-test perf makes it)") }
        let before = halo.probeSamples("viewer-drag").count

        halo.health("viewer-drag", pid: pid, series: "viewer-drag") {
            let scale = NSScreen.main?.backingScaleFactor ?? 1, span = canvas.frame.width * 0.3
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click(
                forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.6)),
                withVelocity: XCUIGestureVelocity(span * scale / 3), thenHoldForDuration: 0.05)
            return []
        }

        let steps = halo.probeSamples("viewer-drag").dropFirst(before).map { ($0.shownAt - $0.eventTime) * 1000 }
        XCTAssertGreaterThan(steps.count, 10, "the drag reached the viewer \(steps.count) times")
        if let p95 = Journey.p95(steps) {
            print(String(format: "realperf Halo viewer-drag real time: %d steps, p95 %.1f ms (target 8, hard 16)", steps.count, p95))
            XCTAssertLessThanOrEqual(p95, 16, "viewer drag step p95 \(p95) ms over the 16 ms hard limit")
        }
    }
}
