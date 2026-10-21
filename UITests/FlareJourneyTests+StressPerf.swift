// FlareJourneyTests+StressPerf.swift: Flare's stress journey, the beta quality gate on a complex file. The
// bundled Flare opens `-FlareSample stress` (FlareFixtures.stress: 200 layers, 500 ten-anchor pen stars, 5,000
// anchors, 600 keys over 600 frames) in a 1600 x 900 window and drives: Select All (⌘A), a drag of everything by
// the first star, ⌘Z; Direct Select (A) and a marquee from the empty corner over the dense top-left half (about
// 120 stars, 1,200 anchors), a drag of those by the first star, ⌘Z; then on the timeline a scrub of the Frame
// Ruler from 0 to 599, the keys at frame 300 picked on every lane on screen (click, then Shift-click) and dragged
// ten frames right, ⌘Z; and Play for 5 s. Direct Select picks items, not single anchors, until #390 lands, and
// the timeline has no Select All Keys, so the keys are the ones on screen. Scene points map through
// `suite.canvas.artboard`; a ruler frame's x is 8 pt in plus its share of the width less 24 (as
// FlareTimelineScrubJourneyTests). Every gesture goes through Journey.health: step p95 where a series records
// (`canvas-drag`, `key-drag`), main-thread surface allocation, the accessibility answer and idle CPU. Only
// `scripts/ui-test perf` runs it (perf-nightly at 04:30); Tests/render-budgets.md records what it measured.
import AppKit
import XCTest

final class FlareStressPerfJourneyTests: XCTestCase {
    @MainActor func testStress() {
        let flare = Journey.realPerf("Flare", self, arguments: ["-FlareSample", "stress", "-SuiteWindowSize", "1600x900", "-SuitePerfProbe"])
        let artboard = flare.element("suite.canvas.artboard")
        guard artboard.waitForExistence(timeout: 120) else { return XCTFail("stress showed no stage (suite.canvas.artboard)") }
        guard let pid = flare.pid(of: "Flare") else { return XCTFail("no running Flare from .build/realperf (scripts/ui-test perf makes it)") }
        let scene = (width: 1100.0, height: 800.0)
        let at = { (x: Double, y: Double) in artboard.coordinate(withNormalizedOffset: CGVector(dx: x / scene.width, dy: y / scene.height)) }
        let points = { (length: Double) in artboard.frame.width * length / scene.width }
        let starOne = (22.0, 22.0)  // the middle of the first star, on Stars 1

        flare.health("select-all", pid: pid, series: nil) { Journey.timed { flare.press(character: "a", .command) } }
        flare.health("drag-all", pid: pid, series: "canvas-drag") {
            Journey.drag(at(starOne.0, starOne.1), to: at(322, 172), distance: points(335))
            return []
        }
        flare.health("undo-all", pid: pid, series: nil) { Journey.timed { flare.press(character: "z", .command) } }

        flare.press(character: "a")
        flare.health("direct-marquee", pid: pid, series: "canvas-drag") {
            Journey.drag(at(4, 4), to: at(550, 400), distance: points(675))
            return []
        }
        flare.health("drag-marquee", pid: pid, series: "canvas-drag") {
            Journey.drag(at(starOne.0, starOne.1), to: at(222, 122), distance: points(224))
            return []
        }
        flare.health("undo-marquee", pid: pid, series: nil) { Journey.timed { flare.press(character: "z", .command) } }
        flare.press(character: "v")

        let ruler = flare.app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Frame Ruler'")).firstMatch
        guard ruler.waitForExistence(timeout: 10) else { return XCTFail("no Frame Ruler in the timeline") }
        let frameX = { (frame: Double) in 8 + (ruler.frame.width - 24 - 8) * frame / 599 }
        let origin = ruler.coordinate(withNormalizedOffset: .zero)
        flare.health("scrub", pid: pid, series: nil) {
            Journey.timed {
                Journey.drag(origin.withOffset(CGVector(dx: frameX(0), dy: 6)), to: origin.withOffset(CGVector(dx: frameX(599), dy: 6)),
                             distance: frameX(599) - frameX(0))
            }
        }

        let timeline = flare.element("flare.timeline")
        let keys = (1...200).lazy.map { lane in
            timeline.descendants(matching: .any).matching(NSPredicate(
                format: "label == %@ AND elementType != %d", "Stars \(lane)", XCUIElement.ElementType.button.rawValue)).firstMatch
                .descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Key at frame 300,'")).firstMatch
        }
        var picked = 0
        for key in keys {
            guard key.exists, key.isHittable else { break }
            if picked == 0 { key.click() } else { XCUIElement.perform(withKeyModifiers: .shift) { key.click() } }
            picked += 1
        }
        if let first = keys.first, picked > 0 {
            print("realperf flare stress: picked the key at 300 on \(picked) lanes")
            flare.health("move-keys", pid: pid, series: "key-drag") {
                let grab = first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let ten = frameX(310) - frameX(300)
                Journey.drag(grab, to: grab.withOffset(CGVector(dx: ten, dy: 0)), distance: ten)
                return []
            }
            flare.press(character: "z", .command)
        } else {
            XCTFail("no key at frame 300 on screen (Stars 1's lane)")
        }

        let play = flare.element("flare.timeline.togglePlay")
        if play.waitForExistence(timeout: 5) {
            flare.health("play-5s", pid: pid, series: nil) {
                Journey.timed {
                    play.click()
                    Thread.sleep(forTimeInterval: 5)
                    play.click()
                }
            }
        } else {
            XCTFail("no play button (flare.timeline.togglePlay)")
        }
    }
}
