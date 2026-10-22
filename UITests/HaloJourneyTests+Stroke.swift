// HaloJourneyTests+Stroke.swift: J-HK, a star's stroke drawn on (stroke-style;
// docs/blueprints/halo/features/stroke-style.md, Journey steps, numbered
// below). On `-HaloSample three-layers` (Intro, 72 frames at 24 fps) it draws
// a star with the Shape button by the viewer (as J-HS), clicks Add Stroke in
// STROKE (SuiteUI's `suite.stroke.*` rows, as SuiteJourneyTests+Stroke reads
// them), types Width 8 and picks the Round join, keys Trim End at 0% at frame
// 0 (the trim row's stopwatch, HK-3's `halo.inspector.key.trimEnd`, the
// row's one control until it animates) and 100% at frame 24, where the
// diamond (`halo.inspector.key.trimEnd.diamond`) shows, then renders frames
// 0, 12 and 24 with ⌘R. The viewer is read by the label of
// `halo.viewer.summary`. HK-2 wrote it skipped; HK-7 turned it on, on live
// services. One shot per step, `halo-stroke-<step>`.
import XCTest

final class HaloStrokeJourneyTests: XCTestCase {
    /// J-HK: Add Stroke on a star, 8 pt round, Trim End keyed 0 → 100% over a second draws the outline on.
    @MainActor func testStrokeDrawOn() throws {
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "three-layers", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        drawStar(halo)

        // 1. Add Stroke: a 1 pt black stroke; the editor shows Width, Join, Cap, Dash and Trim.
        let add = halo.element("suite.stroke.add")
        XCTAssert(add.waitForExistence(timeout: 5), "STROKE has no Add Stroke (suite.stroke.add)")
        XCTAssert(add.isEnabled, "Add Stroke is off: \(add.label)")
        add.click()
        for row in ["width", "join.round", "cap.round", "dash.dashed", "trim-start", "trim-end", "trim-offset"]
        where !halo.element("suite.stroke.\(row)").waitForExistence(timeout: 5) { XCTFail("no suite.stroke.\(row)") }
        let stopwatch = halo.element("halo.inspector.key.trimEnd")
        XCTAssert(stopwatch.waitForExistence(timeout: 5), "Trim End has no stopwatch (halo.inspector.key.trimEnd)")
        XCTAssert(stopwatch.isEnabled, "Trim End's stopwatch is off on live services")
        halo.shot("stroke-1-added")

        // 2. Width 8, Round join: the stroke stays on, its editor live (the viewer's pixels are HK-5's tests).
        type("8", into: "suite.stroke.width", halo)
        let round = halo.element("suite.stroke.join.round")
        XCTAssert(round.isEnabled, "the Round join is off")
        round.click()
        XCTAssert(halo.element("suite.stroke.remove").exists, "Width 8 and Round dropped the stroke")
        XCTAssertFalse(halo.element("suite.stroke.add").exists, "Add Stroke is back after Width 8 and Round")
        halo.shot("stroke-2-round")

        // 3. Trim End keyed 0% at 0 s and 100% at 1 s: the stopwatch keys it, the diamond shows.
        scrub(to: 0, halo)
        type("0", into: "suite.stroke.trim-end", halo)
        stopwatch.click()
        let diamond = halo.element("halo.inspector.key.trimEnd.diamond")
        XCTAssert(diamond.waitForExistence(timeout: 5), "the stopwatch didn't animate Trim End (no diamond)")
        scrub(to: 24, halo)
        type("100", into: "suite.stroke.trim-end", halo)
        XCTAssert(diamond.waitForExistence(timeout: 5), "Trim End lost its diamond at frame 24")
        halo.shot("stroke-3-keyed")

        // 4. Frames 0, 12 and 24 render: nothing, half, the whole outline (HK-6 checks the pixels).
        let summary = halo.element("halo.viewer.summary")
        for frame in [0, 12, 24] {
            scrub(to: frame, halo)
            halo.press(character: "r", .command)
            XCTAssert(halo.element("halo.viewer.rendered").waitForExistence(timeout: 10), "⌘R showed no frame \(frame)")
            XCTAssert(
                FirstFive.wait(3) { summary.label.hasPrefix("Frame \(frame):") }, "the artboard reads \(summary.label)")
            halo.shot("stroke-4-frame-\(frame)")
        }
    }

    /// The Shape button, Star, and a drag across the viewer: a new selected "Star" layer.
    @MainActor private func drawStar(_ halo: Journey) {
        let button = halo.element("halo.viewer.shape")
        XCTAssert(button.waitForExistence(timeout: 10), "no Shape button (halo.viewer.shape)")
        button.click()
        let star = halo.element("suite.shape.chip-star")
        XCTAssert(star.waitForExistence(timeout: 5), "the Shape popover has no Star chip")
        star.click()
        halo.press(.escape)
        let canvas = halo.element("halo.viewer.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "no artboard (halo.viewer.canvas)")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.3)).click(
            forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.7)),
            withVelocity: 100, thenHoldForDuration: 0.1)
        let header = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.inspector.header' AND label CONTAINS %@", "Star")).firstMatch
        XCTAssert(header.waitForExistence(timeout: 5), "no Star layer selected")
    }

    /// Double-clicks the slider row `id` and types `text` into it.
    @MainActor private func type(_ text: String, into id: String, _ halo: Journey) {
        let row = halo.element(id)
        XCTAssert(row.waitForExistence(timeout: 5), "no \(id)")
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
        halo.app.typeText(text)
        halo.press(.return)
    }

    /// Clicks Star's title in the timeline (focusing the timeline), then Home and → `frame` times.
    @MainActor private func scrub(to frame: Int, _ halo: Journey) {
        let title = halo.trackName("Star")
        XCTAssert(title.waitForExistence(timeout: 5), "no Star track title in the timeline")
        title.click()
        halo.press(.home)
        for _ in 0..<frame { halo.press(.rightArrow) }
    }
}
