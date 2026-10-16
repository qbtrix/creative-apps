// PhotoJourneyTests+Perf.swift: Photo's perf journeys (blueprint photo 7.1,
// PJ-P1 and PJ-P2; photo-crop CP-7), on `-PhotoFixture large` (4000 x 3000,
// three layers) in a 1800 pt window. PJ-P1 testCanvasDragLatency drags 600 pt
// across the canvas at 300 pt a second with the shared velocity drag, three
// series: the brush (B), the crop (C) and Space-pan (Space held by a posted
// key event, since XCUITest holds only modifier keys; one zoom step past fit
// gives the pan room). PJ-P2 testSliderScrubLatency scrubs the Exposure bar
// slider back and forth at the same speed for 600 pt in all. Each series ends
// with a window shot.
//
// Report-only (QB-L1, QB-L2; docs/review-rubric.md, How gates are set): the
// tests assert only that every series has at least 60 samples. Each writes one
// line per series to .build/ui-screens/photo-perf-<journey>.txt, which the
// contact sheet inlines, and attaches the same lines as "perf-report-<journey>".
// A series counts the `suite.perf` samples its gesture added (`canvas-drag`,
// `bar-slider`) from the frame probe Photo's SuiteWindow publishes
// (`.suiteProbes()`, #330). If a run finds no probe, a series falls back to
// event samples: the drag's measured seconds (less the press and hold) at one
// pointer event per 60 Hz refresh, and its frames late p95 reads n/a.
import AppKit
import CoreGraphics
import XCTest

final class PhotoPerfJourneyTests: XCTestCase {
    /// 7.1's drag: 600 pt at 300 pt a second.
    static let span: CGFloat = 600
    static let speed: CGFloat = 300
    /// The pointer event rate an event-sample count assumes: one per 60 Hz refresh.
    static let eventRate = 60.0
    /// The click before and the hold after each leg of a velocity drag (Journey+Input.swift).
    static let legPause = 0.1

    /// One series' report: its name, sample count, frames late p95 and where the count came from.
    struct Series {
        let name: String
        let samples: Int
        let p95: String
        let source: String
    }

    /// PJ-P1: brush, crop and Space-pan drags on `large`; QB-L1, report-only.
    @MainActor func testCanvasDragLatency() throws {
        let photo = launchLarge()
        let tools = photo.element("suite.tools").buttons
        let canvas = photo.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "no canvas (suite.canvas)")
        // A Move click gives the canvas the keyboard and moves nothing; then B picks the brush.
        tools["Move"].click()
        canvas.click()
        var series = [Series]()
        photo.press(character: "b")
        expectPicked("Brush", photo)
        series.append(canvasDrag("brush", photo, step: "perf-brush"))

        photo.press(character: "c")
        expectPicked("Crop", photo)
        series.append(canvasDrag("crop", photo, step: "perf-crop"))

        // Escape drops the pending crop; Move keeps a drag without Space from painting.
        photo.press(.escape)
        tools["Move"].click()
        expectPicked("Move", photo)
        photo.press(character: "=", .command)
        let unpanned = canvas.frame
        Self.postSpace(down: true)
        addTeardownBlock { PhotoPerfJourneyTests.postSpace(down: false) }
        let pan = canvasDrag("pan", photo, step: "perf-pan")
        Self.postSpace(down: false)
        let panned = canvas.frame != unpanned ? "the canvas scrolled" : "the canvas didn't scroll (Space not held?)"
        series.append(Series(name: pan.name, samples: pan.samples, p95: pan.p95, source: "\(pan.source); \(panned)"))

        report("QB-L1", "PJ-P1", series, file: "canvas-drag", photo)
    }

    /// PJ-P2: the Exposure bar slider scrubbed on `large`; QB-L2, report-only.
    @MainActor func testSliderScrubLatency() throws {
        let photo = launchLarge()
        // The slider has no identifier (its label is Exposure, as is its section's
        // header), so this drags it the way Journey.velocityDrag drags an element.
        let slider = photo.app.sliders["Exposure"]
        XCTAssert(slider.waitForExistence(timeout: 10), "no Exposure slider")
        let width = slider.frame.width
        XCTAssert(width > 20, "the Exposure slider is \(width) pt wide")
        // Legs of 80% of the slider, right then left, until they add up to 600 pt.
        let legs = max(1, Int((Self.span / max(width * 0.8, 1)).rounded(.up)))
        let before = probe("bar-slider", photo)
        var seconds = 0.0
        for leg in 0..<legs {
            let from: CGFloat = leg.isMultiple(of: 2) ? 0.1 : 0.9
            let started = Date()
            slider.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.5)).click(
                forDuration: 0.05, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 1 - from, dy: 0.5)),
                withVelocity: velocity(), thenHoldForDuration: 0.05)
            seconds += Date().timeIntervalSince(started) - Self.legPause
        }
        photo.shot("perf-exposure")
        let exposure = measured("exposure", key: "bar-slider", seconds: seconds, before: before, photo)
        report("QB-L2", "PJ-P2", [exposure], file: "slider-scrub", photo)
    }

    // MARK: Steps

    /// Launches Photo on `large` with the frame probe asked for, and waits for the 4000 x 3000 image.
    @MainActor private func launchLarge() -> Journey {
        let arguments = photoArguments(fixture: "large", windowSize: "1800x820") + ["-SuitePerfProbe"]
        let photo = Journey("Photo", self, arguments: arguments)
        XCTAssert(photo.element("suite.tools").waitForExistence(timeout: 60), "no tool rail (suite.tools)")
        let header = photo.app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "4000 × 3000 px")).firstMatch
        XCTAssert(header.waitForExistence(timeout: 60), "-PhotoFixture large didn't open the 4000 × 3000 px image")
        return photo
    }

    /// Waits for the tool palette to show `tool` picked.
    @MainActor private func expectPicked(_ tool: String, _ photo: Journey) {
        let picked = photo.element("suite.tools").buttons
            .matching(NSPredicate(format: "label == %@ AND selected == true", tool)).firstMatch
        XCTAssert(picked.waitForExistence(timeout: 5), "the rail doesn't show \(tool) picked")
    }

    /// Drags 600 pt (or 80% of the visible canvas, if narrower) left to right
    /// through the middle of the canvas's visible part with the shared velocity
    /// drag, then shoots `step`.
    @MainActor private func canvasDrag(_ name: String, _ photo: Journey, step: String) -> Series {
        let frame = photo.element("suite.canvas").frame
        var area = frame.intersection(photo.app.windows.firstMatch.frame)
        // Zoomed in, the canvas runs under the floating tool palette and the inspector: keep between them.
        let rail = photo.element("suite.tools").frame, inspector = photo.element("suite.inspector").frame
        if rail.maxX > area.minX, rail.maxX < area.maxX {
            area = area.divided(atDistance: rail.maxX - area.minX, from: .minXEdge).remainder
        }
        if inspector.minX > area.minX, inspector.minX < area.maxX { area.size.width = inspector.minX - area.minX }
        guard area.width > 20, area.height > 20, frame.width > 0, frame.height > 0 else {
            XCTFail("no visible canvas to drag on (canvas \(frame), visible \(area))")
            return Series(name: name, samples: 0, p95: "n/a", source: "no visible canvas")
        }
        let reach = min(Self.span, area.width * 0.8), midX = area.midX, midY = area.midY
        let offset = { (x: CGFloat) in CGVector(dx: (x - frame.minX) / frame.width, dy: (midY - frame.minY) / frame.height) }
        let before = probe("canvas-drag", photo)
        let started = Date()
        photo.velocityDrag(
            on: "suite.canvas", from: offset(midX - reach / 2), to: offset(midX + reach / 2), velocity: velocity())
        let seconds = Date().timeIntervalSince(started) - Self.legPause
        photo.shot(step)
        return measured(name, key: "canvas-drag", seconds: seconds, before: before, photo)
    }

    /// 300 pt a second as XCUIGestureVelocity, which counts pixels a second.
    @MainActor private func velocity() -> XCUIGestureVelocity {
        XCUIGestureVelocity(Self.speed * (NSScreen.main?.backingScaleFactor ?? 1))
    }

    /// The series' samples: what `suite.perf` added under `key` since `before`
    /// when the window publishes it, else event samples from the drag's `seconds`.
    @MainActor private func measured(
        _ name: String, key: String, seconds: Double, before: ProbeSummary?, _ photo: Journey
    ) -> Series {
        let after = probe(key, photo)
        let added = (after?.count ?? 0) - (before?.count ?? 0)
        if let after, added > 0 {
            return Series(name: name, samples: added, p95: "\(after.p95FramesLate)", source: "suite.perf \(key) samples")
        }
        let events = Int((max(seconds, 0) * Self.eventRate).rounded(.down))
        let time = String(format: "%.2f", seconds)
        return Series(
            name: name, samples: events, p95: "n/a",
            source: "event samples: \(time) s of drag at 60 Hz; the window published no suite.perf")
    }

    /// The `suite.perf` summary of `key`; nil when the window doesn't publish the probe.
    @MainActor private func probe(_ key: String, _ photo: Journey) -> ProbeSummary? {
        let element = photo.element("suite.perf")
        guard element.exists,
            let document = try? JSONDecoder().decode(ProbeDocument.self, from: Data(element.label.utf8))
        else { return nil }
        return document.latency[key]
    }

    /// Writes one report-only line per series for the contact sheet, attaches
    /// them, and fails a series under 60 samples (never a latency budget).
    @MainActor private func report(_ row: String, _ journey: String, _ series: [Series], file: String, _ photo: Journey) {
        let lines = series.map {
            "\(row) \(journey) \($0.name): samples=\($0.samples) frames-late-p95=\($0.p95) report-only (\($0.source))"
        }
        for line in lines { print(line) }
        // This file is UITests/PhotoJourneyTests+Perf.swift, so its grandparent is the repo root.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appending(path: ".build/ui-screens")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? Data((lines.joined(separator: "\n") + "\n").utf8).write(to: folder.appending(path: "photo-perf-\(file).txt"))
        if let json = try? JSONEncoder().encode(lines) {
            let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
            attachment.name = "perf-report-\(file)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        for one in series {
            XCTAssertGreaterThanOrEqual(
                one.samples, Journey.minimumSamples,
                "\(journey) \(one.name) has \(one.samples) samples, under \(Journey.minimumSamples): its numbers mean nothing")
        }
    }

    /// Space down or up as a posted key event. XCUITest holds only modifier
    /// keys (XCUIElement.perform(withKeyModifiers:)); Space-pan needs Space
    /// held through the drag. 49 is the Space bar's virtual key code (kVK_Space).
    static func postSpace(down: Bool) {
        CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: down)?.post(tap: .cghidEventTap)
    }
}
