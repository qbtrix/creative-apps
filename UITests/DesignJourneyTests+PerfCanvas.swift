// DesignJourneyTests+PerfCanvas.swift: select-several's perf journey P1
// (packet docs/blueprints/design/features/select-several.md, Journey steps
// item 4; SS-b, S-8; blueprint design section 4, P1, and 7.1, QD-S1 to QD-S5).
// On `crowd` (2,000 layers) at 1024 × 768, the Move tool, it drags back and
// forth at 300 pt a second, 600 pt per series in legs that stay on the
// artboard: it presses Rectangle 1 in Frame 1 and moves what that picks to the
// empty band between the first two rows of frames (y 185), then along it;
// draws a rectangle from (40, 600) to (1000, 990), picking Rectangle in the
// tool box before each leg (a drawing tool goes back to Move after one shape);
// resizes the last one by its bottom-right handle; marquees from the page's
// empty bottom-right corner to (5, 5), pressing Escape before each leg so no
// handle of the last selection is under the press. Then one Space-pan across the viewport, and ⌘= and ⌘−
// ten times each. Page points map to the screen through the artboard
// (`suite.canvas.artboard`), as DesignSelectJourneyTests does.
// Report-only (docs/review-rubric.md, How gates are set): a drag series counts
// the `suite.perf` samples it added, or, when the window records none, event
// samples (the drag's seconds at one pointer event per 60 Hz refresh, as
// DesignPerfScrubJourneyTests does); the zoom series times each key's round
// trip (20 keys, so it isn't held to 60). The numbers go to
// .build/ui-screens/perf-design-canvas.json and attach as "perf-design-canvas";
// the test asserts only ≥ 60 samples per drag series. XCUITest can't hold a key
// that isn't a modifier, so Space goes down and up as CGEvents, and a runner
// without post-event access skips the pan by name after the report is written.
import AppKit
import CoreGraphics
import XCTest

final class DesignPerfCanvasJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "crowd", "-SuiteWindowSize", "1024x768", "-SuitePerfProbe"]
    /// The page's width in `crowd` (DesignFixtures.crowd), which sets the artboard's scale.
    static let pageWidth = 1440.0
    static let artboard = "suite.canvas.artboard"
    static let span: CGFloat = 600, speed: CGFloat = 300, eventRate = 60.0, legPause = 0.1
    /// Rectangle 1 of Frame 1 (12, 12, 16, 16): its middle, then two points on the empty band y 160-210.
    static let moveStart = (20.0, 20.0), moveBand = [(1380.0, 185.0), (20.0, 185.0)]
    /// Each drawn rectangle's corners; the resize drags its bottom-right handle to `resizeTo` and back.
    static let drawFrom = (40.0, 600.0), drawTo = (1000.0, 990.0), resizeTo = (400.0, 800.0)
    /// Beyond the last frame's corner (1395, 960), and outside Frame 1's top-left (10, 10).
    static let marqueeFrom = (1430.0, 1015.0), marqueeTo = (5.0, 5.0)

    /// P1: move, draw, resize and marquee at 300 pt/s, a Space-pan, ⌘= and ⌘− ten times; report-only.
    @MainActor func testCanvasDragLatency() throws {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element(Self.artboard).waitForExistence(timeout: 10), "crowd showed no page (\(Self.artboard))")
        var numbers: [String: String] = [:]
        var counts: [(String, Int)] = []
        var skips: [String] = []

        // QD-S1 move: the first leg picks up Rectangle 1; the rest carry it along the band.
        let move = drags(design, step: "perf-canvas-move", stops: [Self.moveStart] + Self.moveBand)
        numbers["QD-S1 P1 move"] = move.summary
        counts.append(("move", move.samples))

        // QD-S2 draw: Rectangle from the tool box, then one shape per leg.
        let rectangle = design.element("suite.tools").buttons["Rectangle"]
        XCTAssert(rectangle.waitForExistence(timeout: 5), "no Rectangle in the tool box (suite.tools)")
        let draw = drags(design, step: "perf-canvas-draw", stops: [Self.drawFrom, Self.drawTo], restart: true) {
            rectangle.click()
        }
        numbers["QD-S2 P1 draw"] = draw.summary
        counts.append(("draw", draw.samples))

        // QD-S3 resize: the last rectangle is selected; its bottom-right handle in and out.
        let resize = drags(design, step: "perf-canvas-resize", stops: [Self.drawTo, Self.resizeTo])
        numbers["QD-S3 P1 resize"] = resize.summary
        counts.append(("resize", resize.samples))

        // QD-S4 marquee: from empty canvas each leg, after Escape clears the selection.
        let marquee = drags(design, step: "perf-canvas-marquee", stops: [Self.marqueeFrom, Self.marqueeTo], restart: true) {
            design.press(.escape)
        }
        numbers["QD-S4 P1 marquee"] = marquee.summary
        counts.append(("marquee", marquee.samples))
        design.press(.escape)

        // QD-S5 pan: one Space held across legs over the viewport's middle.
        if CGPreflightPostEventAccess() {
            var panned = (samples: 0, summary: "")
            holdingSpace { panned = self.pan(design) }
            numbers["QD-S5 P1 pan"] = panned.summary
            counts.append(("pan", panned.samples))
        } else {
            numbers["QD-S5 P1 pan"] = "skipped: the runner can't post a held Space (CGPreflightPostEventAccess is false)"
            skips.append("the runner can't post a held Space (CGPreflightPostEventAccess is false)")
        }

        // QD-S5 zoom: ⌘= ten times, then ⌘− ten times, each key's round trip.
        var trips: [Double] = []
        let keys: [String] = Array(repeating: "=", count: 10) + Array(repeating: "-", count: 10)
        for character in keys {
            let started = Date()
            design.press(character: character, .command)
            trips.append(Date().timeIntervalSince(started) * 1000)
            if trips.count == 10 { design.shot("perf-canvas-zoomed-in") }
        }
        design.shot("perf-canvas-zoomed-out")
        let sorted = trips.sorted(), median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        numbers["QD-S5 P1 zoom"] = "keys=\(trips.count) median-ms=\(String(format: "%.0f", median)) "
            + "longest-ms=\(String(format: "%.0f", sorted.last ?? 0)) report-only (key round trips)"

        let perf = design.element("suite.perf")
        if perf.exists, let document = try? JSONDecoder().decode(ProbeDocument.self, from: Data(perf.label.utf8)) {
            for (series, summary) in document.latency {
                numbers["suite.perf \(series)"] = "samples=\(summary.count) frames-late-p95=\(summary.p95FramesLate)"
            }
        }
        report(numbers)
        for (name, count) in counts {
            XCTAssertGreaterThanOrEqual(count, Journey.minimumSamples, "P1 \(name) has \(count) samples, under \(Journey.minimumSamples)")
        }
        if !skips.isEmpty { throw XCTSkip(skips.joined(separator: "; ")) }
    }

    // MARK: - Steps

    /// Drags through the page points `stops` in order, then back and forth between the last two,
    /// until 600 pt of screen distance; with `restart` every leg is `stops[0]` to `stops[1]`.
    /// `prepare` runs before each leg. Its samples.
    @MainActor private func drags(
        _ design: Journey, step: String, stops: [(Double, Double)], restart: Bool = false,
        prepare: () -> Void = {}
    ) -> (samples: Int, summary: String) {
        let artboard = design.element(Self.artboard)
        let velocity = XCUIGestureVelocity(Self.speed * (NSScreen.main?.backingScaleFactor ?? 1))
        let before = sampleCount(design)
        let last = stops.count - 1
        var travelled: CGFloat = 0, seconds = 0.0, legs = 0
        while travelled < Self.span, legs < 40, last >= 1 {
            // Leg k runs stops[k] to stops[k + 1] until the end, then between the last two.
            let past = max(0, legs + 1 - last)
            let end = restart ? 1 : (legs < last ? legs + 1 : (past.isMultiple(of: 2) ? last : last - 1))
            let start = restart ? 0 : (legs < last ? legs : (end == last ? last - 1 : last))
            let (from, to) = (stops[start], stops[end])
            let scale = artboard.frame.width / Self.pageWidth
            let length = hypot(CGFloat(to.0 - from.0), CGFloat(to.1 - from.1)) * scale
            XCTAssert(length > 20, "\(step): a leg is \(length) pt long")
            if length <= 20 { break }
            prepare()
            let started = Date()
            point(from, on: artboard).click(
                forDuration: 0.05, thenDragTo: point(to, on: artboard),
                withVelocity: velocity, thenHoldForDuration: 0.05)
            seconds += Date().timeIntervalSince(started) - Self.legPause
            travelled += length
            legs += 1
        }
        design.shot(step)
        let added = sampleCount(design) - before
        if added > 0 { return (added, "samples=\(added) report-only (suite.perf samples over \(legs) legs)") }
        let events = Int((max(seconds, 0) * Self.eventRate).rounded(.down))
        let time = String(format: "%.2f", seconds)
        return (events, "samples=\(events) report-only (event samples: \(time) s of drag at 60 Hz; no suite.perf samples)")
    }

    /// Space-drags the viewport between 0.75 and 0.25 of its width, 600 pt in all; its samples.
    @MainActor private func pan(_ design: Journey) -> (samples: Int, summary: String) {
        let viewport = design.element("suite.viewport")
        XCTAssert(viewport.waitForExistence(timeout: 5), "no suite.viewport to pan")
        let width = viewport.frame.width
        let legs = max(1, Int((Self.span / max(width * 0.5, 1)).rounded(.up)))
        let velocity = XCUIGestureVelocity(Self.speed * (NSScreen.main?.backingScaleFactor ?? 1))
        let before = sampleCount(design)
        var seconds = 0.0
        for leg in 0..<legs {
            let from: CGFloat = leg.isMultiple(of: 2) ? 0.75 : 0.25
            let started = Date()
            viewport.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.5)).click(
                forDuration: 0.05, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 1 - from, dy: 0.5)),
                withVelocity: velocity, thenHoldForDuration: 0.05)
            seconds += Date().timeIntervalSince(started) - Self.legPause
        }
        design.shot("perf-canvas-pan")
        let added = sampleCount(design) - before
        if added > 0 { return (added, "samples=\(added) report-only (suite.perf samples over \(legs) legs)") }
        let events = Int((max(seconds, 0) * Self.eventRate).rounded(.down))
        let time = String(format: "%.2f", seconds)
        return (events, "samples=\(events) report-only (event samples: \(time) s of pan at 60 Hz; no suite.perf samples)")
    }

    /// Runs `body` with Space held down, posted as CGEvents (virtual key 49).
    @MainActor private func holdingSpace(_ body: () -> Void) {
        CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.2)
        body()
        CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: false)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.2)
    }

    /// The screen point of the page point: the artboard's corner plus the point at its scale.
    @MainActor private func point(_ page: (Double, Double), on artboard: XCUIElement) -> XCUICoordinate {
        let scale = artboard.frame.width / Self.pageWidth
        return artboard.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: page.0 * scale, dy: page.1 * scale))
    }

    /// How many samples `suite.perf` holds; 0 when the window publishes none.
    @MainActor private func sampleCount(_ design: Journey) -> Int {
        let perf = design.element("suite.perf")
        guard perf.exists, let document = try? JSONDecoder().decode(ProbeDocument.self, from: Data(perf.label.utf8)) else { return 0 }
        return document.samples.count
    }

    /// Writes the report-only numbers to .build/ui-screens/perf-design-canvas.json and attaches them.
    @MainActor private func report(_ numbers: [String: String]) {
        for (key, value) in numbers.sorted(by: { $0.key < $1.key }) { print("\(key): \(value)") }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let json = try? encoder.encode(numbers) else { return }
        // This file is UITests/DesignJourneyTests+PerfCanvas.swift, so its grandparent is the repo root.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appending(path: ".build/ui-screens")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? json.write(to: folder.appending(path: "perf-design-canvas.json"))
        let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        attachment.name = "perf-design-canvas"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
