// DesignJourneyTests+PerfScrub.swift: style-rows' perf journey P2 (packet
// docs/blueprints/design/features/style-rows.md, Journey steps item 3; SR-b,
// ST-8; quality rows QD-S7 and QD-S6). On `crowd` (2,000 layers) at
// 1024 × 768 it selects Frame 36's Text row in Layers, drags the Opacity bar
// back and forth for 600 pt at 300 pt a second, double-clicks the Text on the
// canvas and types a 30-character line into the inline editor twice (⌘A
// between, 60 keystrokes), commits it with Return, then drags the X scrub
// field the same way. A Layers row is clicked in its blank space between the
// name and the Hide toggle: a click on the name doesn't select it (#2496).
// Report-only (docs/review-rubric.md, How gates are set): a drag series counts
// the `suite.perf` samples it added, or, when the window records none, event
// samples (the drag's seconds at one pointer event per 60 Hz refresh, as
// PhotoJourneyTests+Perf does); the typing series times each keystroke's round
// trip. The numbers go to .build/ui-screens/perf-design-scrub.json and attach
// as "perf-design-scrub"; the test asserts only ≥ 60 samples per series.
import AppKit
import XCTest

final class DesignPerfScrubJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "crowd", "-SuiteWindowSize", "1024x768", "-SuitePerfProbe"]
    /// Frame 36 (node-(50N - 49)), its Text (node-50N) and that Text's middle on the 1440 × 1024 page.
    static let frameRow = "design.layer.node-1751", textRow = "design.layer.node-1800"
    static let insideText = CGVector(dx: 615 / 1440.0, dy: 946 / 1024.0)
    static let opacity = "design.inspector.opacity", positionX = "design.inspector.x"
    static let line = "The quick brown fox jumps over"  // 30 characters
    static let span: CGFloat = 600, speed: CGFloat = 300, eventRate = 60.0, legPause = 0.1

    /// P2: the Opacity bar and X field scrubbed, 30 characters typed twice; report-only.
    @MainActor func testScrubLatency() {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let canvas = design.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "crowd showed no page (suite.canvas)")
        design.expandDesignLayer(Self.frameRow)
        design.clickDesignLayer(Self.textRow)
        var numbers: [String: String] = [:]

        let opacity = scrub(design, Self.opacity, step: "perf-scrub-opacity")
        numbers["QD-S7 P2 opacity-bar"] = opacity.summary

        canvas.coordinate(withNormalizedOffset: Self.insideText).doubleClick()
        XCTAssert(design.element("design.text").waitForExistence(timeout: 5), "double-clicking Frame 36's Text opened no editor")
        var trips: [Double] = []
        for round in 0..<2 {
            design.press(character: "a", .command)
            for character in Self.line {
                let started = Date()
                design.app.typeText(String(character))
                trips.append(Date().timeIntervalSince(started) * 1000)
            }
            if round == 0 { design.shot("perf-scrub-typing") }
        }
        design.press(.return)
        let sorted = trips.sorted(), median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        numbers["QD-S6 P2 typing"] = "samples=\(trips.count) median-ms=\(String(format: "%.0f", median)) "
            + "longest-ms=\(String(format: "%.0f", sorted.last ?? 0)) report-only (keystroke round trips)"

        let positionX = scrub(design, Self.positionX, step: "perf-scrub-x")
        numbers["QD-S7 P2 x-field"] = positionX.summary

        let perf = design.element("suite.perf")
        if perf.exists, let document = try? JSONDecoder().decode(ProbeDocument.self, from: Data(perf.label.utf8)) {
            for (series, summary) in document.latency {
                numbers["suite.perf \(series)"] = "samples=\(summary.count) frames-late-p95=\(summary.p95FramesLate)"
            }
        }
        report(numbers)
        for (name, count) in [("opacity-bar", opacity.samples), ("typing", trips.count), ("x-field", positionX.samples)] {
            XCTAssertGreaterThanOrEqual(count, Journey.minimumSamples, "P2 \(name) has \(count) samples, under \(Journey.minimumSamples)")
        }
    }

    // MARK: - Steps

    /// Drags the bar `identifier` across 80% of its width, right then left, for 600 pt in all; its samples.
    @MainActor private func scrub(_ design: Journey, _ identifier: String, step: String) -> (samples: Int, summary: String) {
        let bar = design.element("suite.inspector").descendants(matching: .any)[identifier].firstMatch
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(identifier) in the inspector")
        let width = bar.frame.width
        XCTAssert(width > 20, "\(identifier) is \(width) pt wide")
        let legs = max(1, Int((Self.span / max(width * 0.8, 1)).rounded(.up)))
        let before = sampleCount(design)
        let velocity = XCUIGestureVelocity(Self.speed * (NSScreen.main?.backingScaleFactor ?? 1))
        var seconds = 0.0
        for leg in 0..<legs {
            let from: CGFloat = leg.isMultiple(of: 2) ? 0.1 : 0.9
            let started = Date()
            bar.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.5)).click(
                forDuration: 0.05, thenDragTo: bar.coordinate(withNormalizedOffset: CGVector(dx: 1 - from, dy: 0.5)),
                withVelocity: velocity, thenHoldForDuration: 0.05)
            seconds += Date().timeIntervalSince(started) - Self.legPause
        }
        design.shot(step)
        let added = sampleCount(design) - before
        if added > 0 { return (added, "samples=\(added) report-only (suite.perf samples over \(legs) legs)") }
        let events = Int((max(seconds, 0) * Self.eventRate).rounded(.down))
        let time = String(format: "%.2f", seconds)
        return (events, "samples=\(events) report-only (event samples: \(time) s of drag at 60 Hz; no suite.perf samples)")
    }

    /// How many samples `suite.perf` holds; 0 when the window publishes none.
    @MainActor private func sampleCount(_ design: Journey) -> Int {
        let perf = design.element("suite.perf")
        guard perf.exists, let document = try? JSONDecoder().decode(ProbeDocument.self, from: Data(perf.label.utf8)) else { return 0 }
        return document.samples.count
    }

    /// Writes the report-only numbers to .build/ui-screens/perf-design-scrub.json and attaches them.
    @MainActor private func report(_ numbers: [String: String]) {
        for (key, value) in numbers.sorted(by: { $0.key < $1.key }) { print("\(key): \(value)") }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let json = try? encoder.encode(numbers) else { return }
        // This file is UITests/DesignJourneyTests+PerfScrub.swift, so its grandparent is the repo root.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appending(path: ".build/ui-screens")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? json.write(to: folder.appending(path: "perf-design-scrub.json"))
        let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        attachment.name = "perf-design-scrub"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
