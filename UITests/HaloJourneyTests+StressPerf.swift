// HaloJourneyTests+StressPerf.swift: Halo's stress journey, the beta quality gate on a long timeline. The bundled
// Halo opens `-HaloSample crowd` (HaloFixtures.crowd: 300 solids, 5,000 keys over 300 frames, more than the
// gate's 200 layers and 600 keys, so no new fixture) in a 1600 x 900 window and drives: a scrub, Solid 300's
// track title clicked (which focuses the timeline) then → held for about 3 s, one frame per press; End and Home
// back and forth for 3 s; and Play for 5 s. Halo can pick keys but not move them, and has no Select All Keys, so
// the key move the gate asks for is Flare's alone (FlareStressPerfJourneyTests). Every gesture goes through
// Journey.health: the accessibility answer, main-thread surface allocation and idle CPU; none records a
// `suite.perf` series, so the step times are round trips, reported, not gated. Only `scripts/ui-test perf` runs
// it (perf-nightly at 04:30); Tests/render-budgets.md records what it measured.
import AppKit
import XCTest

final class HaloStressPerfJourneyTests: XCTestCase {
    @MainActor func testStress() {
        let halo = Journey.realPerf("Halo", self, arguments: ["-HaloSample", "crowd", "-HaloWindowSize", "1600x900", "-SuitePerfProbe"])
        let title = halo.trackName("Solid 300")
        guard title.waitForExistence(timeout: 120) else { return XCTFail("crowd showed no Solid 300 track (halo.timeline.name.*)") }
        guard let pid = halo.pid(of: "Halo") else { return XCTFail("no running Halo from .build/realperf (scripts/ui-test perf makes it)") }
        title.click()

        halo.health("scrub", pid: pid, series: nil) { Journey.repeatFor(seconds: 3) { _ in halo.press(.rightArrow) } }
        halo.health("jump", pid: pid, series: nil) {
            Journey.repeatFor(seconds: 3) { step in halo.press(step.isMultiple(of: 2) ? .end : .home) }
        }

        let play = halo.element("halo.transport.play")
        guard play.waitForExistence(timeout: 5) else { return XCTFail("no Play button (halo.transport.play)") }
        halo.health("play-5s", pid: pid, series: nil) {
            Journey.timed {
                play.click()
                Thread.sleep(forTimeInterval: 5)
                play.click()
            }
        }
    }
}
