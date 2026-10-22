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
// most 80% of it, with as many legs as make up 4 × 600 pt, and a leg slows
// below 300 pt a second so it lasts at least `legTime`: each viewer leg must
// hold 60 samples of its own (#4276), split by when the test started it. The
// Rotation bar's legs run from dx 0.05 to 0.95 and last `legTime` each, so a
// scrub spans 60 refreshes or more (#4275). H-P5 scrolls with bursts of
// `burstEvents` posted scroll-wheel events, one every 120th of a second,
// before each XCUITest scroll call (which alone draws one frame per call,
// about 1.5 s apart), and counts only the intervals between two frames drawn
// inside one burst (#4277).
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
    /// The shortest drag leg, in seconds: 72 or more 60 Hz refreshes.
    static let legTime: CGFloat = 1.2
    /// Scroll-wheel events per burst, and the pixels each one scrolls.
    static let burstEvents = 24, burstPixels: Int32 = 3

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
        var starts: [Double] = []
        for leg in 0..<legs {
            let (from, to) = leg.isMultiple(of: 2) ? (start, far) : (far, start)
            starts.append(ProcessInfo.processInfo.systemUptime)
            halo.velocityDrag(on: "halo.viewer.canvas", from: from, to: to, velocity: velocity(lasting: span))
        }
        halo.shot("perf-viewer-drag")
        guard let document = halo.perf() else { return }
        halo.expectValid(document, series: "viewer-drag")
        // Each sample belongs to the last leg started before its event.
        let times = document.samples.filter { $0.series == "viewer-drag" }.map(\.eventTime)
        let perLeg = starts.indices.map { leg in
            times.filter { $0 >= starts[leg] && (leg + 1 == starts.count || $0 < starts[leg + 1]) }.count
        }
        XCTAssert(
            perLeg.allSatisfy { $0 >= Journey.minimumSamples },
            "viewer-drag samples per leg \(perLeg), some under \(Journey.minimumSamples): a leg's numbers mean nothing")
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
        // H-J6 drags the bar from 0.3 to 0.7; here 0.05 to 0.95 and back until 600 pt.
        let travel = width * 0.9
        let legs = max(2, Int((Self.legSpan / max(travel, 1)).rounded(.up)))
        let left = CGVector(dx: 0.05, dy: 0.5), right = CGVector(dx: 0.95, dy: 0.5)
        let stops = (1...legs).map { $0.isMultiple(of: 2) ? left : right }
        halo.velocityDrag(
            on: "halo.inspector.row.rotation", from: left, through: Array(stops.dropLast()), to: stops.last ?? right,
            velocity: velocity(lasting: travel), step: "perf-inspector-scrub")
        guard let document = halo.perf() else { return }
        halo.expectValid(document, series: "inspector-scrub")
    }

    /// H-P3, `reference`: velocity drags on the Frame Ruler from dx 0.02 to
    /// 0.98 and back, as many legs as make up 4 × 600 pt; series
    /// `playhead-scrub` (HB-U3). The drags press on the ruler itself: dx 0.02
    /// of `halo.timeline` is the empty name-column cell left of the ruler,
    /// where a press starts no scrub, so no sample was taken (#4265).
    @MainActor func testPlayheadScrubLatency() {
        let halo = launch("reference")
        XCTAssert(halo.element("halo.timeline").waitForExistence(timeout: 10), "no timeline (halo.timeline)")
        let ruler = halo.app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Frame Ruler'")).firstMatch
        XCTAssert(ruler.waitForExistence(timeout: 10), "no Frame Ruler in the timeline")
        let width = ruler.frame.width
        XCTAssertGreaterThan(width, 20, "the Frame Ruler is \(width) pt wide")
        let left = CGVector(dx: 0.02, dy: 0.5), right = CGVector(dx: 0.98, dy: 0.5)
        let legs = max(Self.legCount, Int((Self.legSpan * CGFloat(Self.legCount) / max(width * 0.96, 1)).rounded(.up)))
        for leg in 0..<legs {
            let (from, to) = leg.isMultiple(of: 2) ? (left, right) : (right, left)
            ruler.coordinate(withNormalizedOffset: from).click(
                forDuration: 0.05, thenDragTo: ruler.coordinate(withNormalizedOffset: to),
                withVelocity: velocity(lasting: .infinity), thenHoldForDuration: 0.05)
        }
        halo.shot("perf-playhead-scrub")
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
        XCTAssert(CGPreflightPostEventAccess(), "the runner may not post scroll-wheel events, so no scroll burst")
        let lanes = halo.element("halo.timeline")
        XCTAssert(lanes.waitForExistence(timeout: 10), "no timeline (halo.timeline)")
        var lanesBursts: [ClosedRange<Double>] = [], listBursts: [ClosedRange<Double>] = []
        scrollEnd(lanes, until: halo.trackName("Solid 1"), by: -120, bursts: &lanesBursts)
        halo.shot("perf-lanes-bottom")
        expectNoScroller(over: lanes, halo)
        scrollEnd(lanes, until: halo.trackName("Solid 300"), by: 120, bursts: &lanesBursts)

        let list = halo.element("halo.layer.list")
        XCTAssert(list.waitForExistence(timeout: 10), "no layer list (halo.layer.list)")
        scrollEnd(list, until: halo.element("halo.layer.row.comp-1-layer-1"), by: -120, bursts: &listBursts)
        halo.shot("perf-layers-bottom")
        scrollEnd(list, until: halo.element("halo.layer.row.comp-1-layer-300"), by: 120, bursts: &listBursts)
        guard let document = halo.perf() else { return }
        expectBurstIntervals(document, series: "lanes-scroll", bursts: lanesBursts)
        expectBurstIntervals(document, series: "layers-scroll", bursts: listBursts)
    }

    // MARK: - Steps

    /// 300 pt a second in the screen's pixels, or slower so a leg of
    /// `points` lasts at least `legTime`.
    @MainActor private func velocity(lasting points: CGFloat) -> XCUIGestureVelocity {
        XCUIGestureVelocity(min(Self.speed, points / Self.legTime) * (NSScreen.main?.backingScaleFactor ?? 1))
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

    /// Scrolls `area` by `delta` until `target` is hittable, at most 300
    /// times; before each scroll call, a burst of `burstEvents` wheel events
    /// the same way at 120 Hz over its centre, its uptime span (and 50 ms
    /// for the last frame) added to `bursts`.
    @MainActor private func scrollEnd(
        _ area: XCUIElement, until target: XCUIElement, by delta: CGFloat, bursts: inout [ClosedRange<Double>]
    ) {
        let centre = area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).screenPoint
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: centre, mouseButton: .left)?
            .post(tap: .cghidEventTap)
        let pixels = delta < 0 ? -Self.burstPixels : Self.burstPixels
        var scrolls = 0
        while !(target.exists && target.isHittable), scrolls < 300 {
            let begin = ProcessInfo.processInfo.systemUptime
            for _ in 0..<Self.burstEvents {
                let wheel = CGEvent(
                    scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: pixels, wheel2: 0, wheel3: 0)
                wheel?.location = centre
                wheel?.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 1.0 / 120)
            }
            bursts.append(begin...(ProcessInfo.processInfo.systemUptime + 0.05))
            area.scroll(byDeltaX: 0, deltaY: delta)
            scrolls += 1
        }
        XCTAssert(target.exists && target.isHittable, "\(scrolls) scrolls didn't reach \(target.identifier)")
    }

    /// Attaches the intervals of `series` between two frames drawn inside one
    /// of `bursts`, in refreshes ("scroll-bursts-<series>": count and p95);
    /// fails when there are fewer than 60.
    @MainActor private func expectBurstIntervals(
        _ document: ProbeDocument, series: String, bursts: [ClosedRange<Double>]
    ) {
        let frames = document.drawn[series] ?? []
        let refresh = document.refreshInterval > 0 ? document.refreshInterval : 1.0 / 60
        let gaps = zip(frames, frames.dropFirst())
            .filter { pair in bursts.contains { $0.contains(pair.0) && $0.contains(pair.1) } }
            .map { ($1 - $0) / refresh }.sorted()
        let p95 = gaps.isEmpty ? 0 : gaps[min(gaps.count - 1, Int((Double(gaps.count) * 0.95).rounded(.down)))]
        let attachment = XCTAttachment(
            string: "\(series): \(gaps.count) in-burst intervals over \(bursts.count) bursts, p95 \(p95) refreshes")
        attachment.name = "scroll-bursts-\(series)"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssert(
            gaps.count >= Journey.minimumSamples,
            "series \(series) has \(gaps.count) in-burst intervals, under \(Journey.minimumSamples): its numbers mean nothing")
    }

    /// Fails when a scroll bar shows over `area`: a legacy scroller's page
    /// areas are unnamed buttons with no identifier to the app audit (#4264, #4266).
    @MainActor private func expectNoScroller(over area: XCUIElement, _ halo: Journey) {
        let frame = area.frame
        for bar in halo.app.windows.firstMatch.scrollBars.allElementsBoundByIndex where bar.isHittable {
            XCTAssertFalse(bar.frame.intersects(frame), "a scroll bar \(bar.frame) shows over \(area.identifier) \(frame)")
        }
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
