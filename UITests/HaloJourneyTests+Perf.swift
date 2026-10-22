// HaloJourneyTests+Perf.swift: Halo's perf journeys H-P1 to H-P5 (packet
// docs/blueprints/halo/features/core-loop.md, Journey steps and Quality
// tests; blueprint halo 7.1, HB-U1 to HB-U4 and QB-L10's UI half). Each
// journey launches on `-HaloSample reference` (50 keyed layers, 300 frames at
// 30 fps) or `crowd` (300 solids) with `-SuitePerfProbe` and ends with
// `perf()` (Journey+Input.swift), which attaches "perf-<test>" and checks the
// gates below through `PerfBudgeted`. Every gate is report-only: `limit` is
// 7.1's CI placeholder and `enforced` stays false until ten green runs on
// `dev`. The series names are HaloProbe's (CL-8): `viewer-drag`,
// `inspector-scrub` and `playhead-scrub` take samples; `playback`,
// `lanes-scroll` and `layers-scroll` record drawn frames. Each test fails
// only a series with fewer than 60 samples or intervals, never its timing.
// The viewer drag presses at the selected layer's position (its TRANSFORM
// rows, as H-J5 aims), so the press hits a drawn layer and starts a drag, and
// each leg starts where the last one left that layer. At the runners'
// 1000 by 640 window the artboard is narrower than 600 pt, so a leg spans at
// most 80% of it, with as many legs as make up 4 × 600 pt.
// XCUIGestureVelocity is pixels a second, so 300 pt a second is scaled by the
// screen's backing scale, as DesignJourneyTests+PerfScrub does.
import AppKit
import XCTest

final class HaloPerfJourneyTests: XCTestCase {
    /// The window every Halo journey uses, so it fits CI's 1024 by 768 display.
    static let window = ["-HaloWindowSize", "1000x640"]
    /// The sample compositions' size in pixels (HaloFixtures.comp).
    static let compositionSize = CGSize(width: 1920, height: 1080)
    /// A viewer drag leg and the bar scrub's travel, the leg count, and the speed, in points.
    static let legSpan: CGFloat = 600, legCount = 4, speed: CGFloat = 300

    /// H-P1, `reference`: four 600 pt viewer drags at 300 pt/s on
    /// `halo.viewer.canvas`; series `viewer-drag` (HB-U1).
    @MainActor func testViewerDragLatency() {
        let halo = launch("reference")
        selectTopLayer(halo)
        let canvas = halo.element("halo.viewer.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "reference drew no artboard (halo.viewer.canvas)")
        let width = canvas.frame.width
        XCTAssertGreaterThan(width, 20, "the artboard is \(width) pt wide")
        let span = min(Self.legSpan, width * 0.8)
        let legs = max(Self.legCount, Int((Self.legSpan * CGFloat(Self.legCount) / max(span, 1)).rounded(.up)))
        let start = CGVector(
            dx: CGFloat(pixels("x", halo) ?? 60) / Self.compositionSize.width,
            dy: CGFloat(pixels("y", halo) ?? 60) / Self.compositionSize.height)
        let far = CGVector(dx: start.dx + span / max(width, 1), dy: start.dy)
        for leg in 0..<legs {
            let (from, to) = leg.isMultiple(of: 2) ? (start, far) : (far, start)
            halo.velocityDrag(on: "halo.viewer.canvas", from: from, to: to, velocity: velocity)
        }
        halo.shot("perf-viewer-drag")
        guard let document = halo.perf() else { return }
        halo.expectValid(document, series: "viewer-drag")
    }

    /// H-P2, `reference`: a velocity drag across the rotation row's bar;
    /// series `inspector-scrub` (HB-U2).
    @MainActor func testInspectorScrubLatency() {
        let halo = launch("reference")
        selectTopLayer(halo)
        let bar = halo.element("halo.inspector.row.rotation")
        XCTAssert(bar.waitForExistence(timeout: 5), "no Rotation bar (halo.inspector.row.rotation)")
        let width = bar.frame.width
        XCTAssertGreaterThan(width, 20, "the Rotation bar is \(width) pt wide")
        // H-J6 drags the bar from 0.3 to 0.7; here right and left again until 600 pt.
        let legs = max(2, Int((Self.legSpan / max(width * 0.4, 1)).rounded(.up)))
        let left = CGVector(dx: 0.3, dy: 0.5), right = CGVector(dx: 0.7, dy: 0.5)
        let stops = (1...legs).map { $0.isMultiple(of: 2) ? left : right }
        halo.velocityDrag(
            on: "halo.inspector.row.rotation", from: left, through: Array(stops.dropLast()), to: stops.last ?? right,
            velocity: velocity, step: "perf-inspector-scrub")
        guard let document = halo.perf() else { return }
        halo.expectValid(document, series: "inspector-scrub")
    }

    /// H-P3, `reference`: a velocity drag on `halo.timeline` from dx 0.02 to
    /// 0.98 at dy 0.05 (the ruler); series `playhead-scrub` (HB-U3).
    @MainActor func testPlayheadScrubLatency() {
        let halo = launch("reference")
        XCTAssert(halo.element("halo.timeline").waitForExistence(timeout: 10), "no timeline (halo.timeline)")
        halo.velocityDrag(
            on: "halo.timeline", from: CGVector(dx: 0.02, dy: 0.05), to: CGVector(dx: 0.98, dy: 0.05),
            velocity: velocity, step: "perf-playhead-scrub")
        guard let document = halo.perf() else { return }
        halo.expectValid(document, series: "playhead-scrub")
    }

    /// H-P4, `reference`: Play, 5 s, Pause; series `playback`, intervals (HB-U4).
    @MainActor func testPlaybackHoldsRate() {
        let halo = launch("reference")
        let play = halo.element("halo.transport.play")
        XCTAssert(play.waitForExistence(timeout: 10), "no Play button (halo.transport.play)")
        play.click()
        halo.shot("perf-playback-playing")
        Thread.sleep(forTimeInterval: 5)
        play.click()
        halo.shot("perf-playback-paused")
        guard let document = halo.perf() else { return }
        expectIntervals(document, series: "playback")
    }

    /// H-P5, `crowd`: the lanes and the layer list scrolled end to end;
    /// series `lanes-scroll` and `layers-scroll`, intervals (QB-L10).
    @MainActor func testTimelineAndLayerListScroll() {
        let halo = launch("crowd")
        // crowd lists Solid 300 first and Solid 1 last, in the lanes and in the layer list.
        let lanes = halo.element("halo.timeline")
        XCTAssert(lanes.waitForExistence(timeout: 10), "no timeline (halo.timeline)")
        scrollEnd(lanes, until: halo.trackName("Solid 1"), by: -120)
        halo.shot("perf-lanes-bottom")
        scrollEnd(lanes, until: halo.trackName("Solid 300"), by: 120)

        let list = halo.element("halo.layer.list")
        XCTAssert(list.waitForExistence(timeout: 10), "no layer list (halo.layer.list)")
        scrollEnd(list, until: halo.element("halo.layer.row.comp-1-layer-1"), by: -120)
        halo.shot("perf-layers-bottom")
        scrollEnd(list, until: halo.element("halo.layer.row.comp-1-layer-300"), by: 120)
        guard let document = halo.perf() else { return }
        expectIntervals(document, series: "lanes-scroll")
        expectIntervals(document, series: "layers-scroll")
    }

    // MARK: - Steps

    /// 300 pt a second in the screen's pixels.
    @MainActor private var velocity: XCUIGestureVelocity {
        XCUIGestureVelocity(Self.speed * (NSScreen.main?.backingScaleFactor ?? 1))
    }

    /// Halo on sample `name` with the frame probe on, once its window shows a viewer.
    @MainActor private func launch(_ name: String) -> Journey {
        let halo = Journey("Halo", self, arguments: ["-HaloSample", name] + Self.window + ["-SuitePerfProbe"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(halo.element("halo.viewer").waitForExistence(timeout: 10), "\(name) showed no viewer (halo.viewer)")
        return halo
    }

    /// Clicks the first track's name in the timeline: selects the top layer from its lane.
    @MainActor private func selectTopLayer(_ halo: Journey) {
        let name = halo.app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'halo.timeline.name.'")).firstMatch
        XCTAssert(name.waitForExistence(timeout: 10), "no track (halo.timeline.name.*) in the timeline")
        name.click()
        XCTAssert(
            halo.element("halo.inspector.row.x").waitForExistence(timeout: 5), "selecting a lane showed no TRANSFORM rows")
    }

    /// The pixels TRANSFORM row `raw` reads: the slider's value, or the leading number of its text ("560.0 px").
    @MainActor private func pixels(_ raw: String, _ halo: Journey) -> Double? {
        let value = halo.element("halo.inspector.row.\(raw)").value
        if let number = value as? NSNumber { return number.doubleValue }
        let text = ((value as? String) ?? "").replacingOccurrences(of: "\u{2212}", with: "-")
            .replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        return Double(String(text.prefix { $0.isNumber || $0 == "." || $0 == "-" }))
    }

    /// Scrolls `area` by `delta` until `target` is hittable, at most 300 times.
    @MainActor private func scrollEnd(_ area: XCUIElement, until target: XCUIElement, by delta: CGFloat) {
        var scrolls = 0
        while !(target.exists && target.isHittable), scrolls < 300 {
            area.scroll(byDeltaX: 0, deltaY: delta)
            scrolls += 1
        }
        XCTAssert(target.exists && target.isHittable, "\(scrolls) scrolls didn't reach \(target.identifier)")
    }

    /// Fails when the drawn-frame series `series` has fewer than 60 intervals.
    @MainActor private func expectIntervals(_ document: ProbeDocument, series: String) {
        let count = document.intervals[series]?.count ?? 0
        XCTAssert(
            count >= Journey.minimumSamples,
            "series \(series) has \(count) intervals, under \(Journey.minimumSamples): its numbers mean nothing")
    }
}

extension HaloPerfJourneyTests: PerfBudgeted {
    /// HB-U1, H-P1: viewer drag on screen, frames late (target p95 ≤ 2).
    static let viewerDrag = PerfBudget(row: "HB-U1", series: ["viewer-drag"], measure: .latency, limit: 3)
    /// HB-U2, H-P2: inspector bar on screen (target p95 ≤ 2).
    static let inspectorScrub = PerfBudget(row: "HB-U2", series: ["inspector-scrub"], measure: .latency, limit: 3)
    /// HB-U3, H-P3: playhead on screen (target p95 ≤ 2).
    static let playheadScrub = PerfBudget(row: "HB-U3", series: ["playhead-scrub"], measure: .latency, limit: 3)
    /// HB-U4, H-P4: playback holds its rate, refreshes between drawn frames
    /// (target 0 dropped, jitter p95 < 2 ms).
    static let playback = PerfBudget(row: "HB-U4", series: ["playback"], measure: .intervals, limit: 1.5)
    /// QB-L10's UI half, H-P5: lanes and layer list scroll (target p95 ≤ 1.5
    /// refreshes); the gate is set from CI, so no placeholder.
    static let scroll = PerfBudget(row: "QB-L10", series: ["lanes-scroll", "layers-scroll"], measure: .intervals, limit: nil)

    /// Every row, HB-U1 to HB-U4 then QB-L10.
    static let perfBudgets: [PerfBudget] = [viewerDrag, inspectorScrub, playheadScrub, playback, scroll]
}
