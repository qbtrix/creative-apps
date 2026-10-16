// PhotoJourneyTests+PerfAdjustmentLayers.swift: PJ-P2's adjustment series,
// testAdjustmentLayerScrubLatency (photo-adjustment-layers AL-8; packet
// Journey steps 2, PB-13). On `-PhotoFixture large` (4000 x 3000, three
// layers) in a 1800 pt window it adds an Exposure adjustment layer from
// Layer > New Adjustment Layer and scrubs that layer's Exposure bar slider
// back and forth at 300 pt a second for 600 pt in all, as
// PhotoJourneyTests+Perf.swift's testSliderScrubLatency scrubs the
// whole-image one. Report-only (QB-L2): it asserts only at least 60 samples,
// writes its line to .build/ui-screens/photo-perf-adjustment-layer-scrub.txt
// for the contact sheet and attaches it as
// "perf-report-adjustment-layer-scrub". The samples are the `suite.perf`
// `bar-slider` samples the scrub added once the window publishes the frame
// probe (#330), else event samples (the drag's seconds at 60 Hz), as there.
import AppKit
import CoreGraphics
import XCTest

extension PhotoJourneyTests {
    /// PJ-P2's adjustment series: an Exposure adjustment layer's bar scrubbed on `large`; QB-L2, report-only.
    @MainActor func testAdjustmentLayerScrubLatency() throws {
        let photo = Journey("Photo", self, arguments: photoArguments(fixture: "large", windowSize: "1800x820") + ["-SuitePerfProbe"])
        XCTAssert(photo.element("suite.tools").waitForExistence(timeout: 60), "no tool rail (suite.tools)")
        let header = photo.app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "4000 × 3000 px")).firstMatch
        XCTAssert(header.waitForExistence(timeout: 60), "-PhotoFixture large didn't open the 4000 × 3000 px image")

        adjChooseAdjustmentLayer("Exposure", photo)
        adjExpect("Undo New Adjustment Layer", photo, "New Adjustment Layer > Exposure made no undo step")
        let adjust = photo.app.radioButtons["Adjust"]
        XCTAssert(adjust.waitForExistence(timeout: 5), "no Adjust tab")
        adjust.click()
        let slider = photo.app.sliders["Exposure"]
        XCTAssert(slider.waitForExistence(timeout: 10), "the Exposure adjustment layer shows no Exposure slider")
        photo.shot("perf-adjustment-layer-added")
        let width = slider.frame.width
        XCTAssert(width > 20, "the Exposure slider is \(width) pt wide")

        // Legs of 80% of the slider, right then left, until they add up to 600 pt.
        let legs = max(1, Int((PhotoPerfJourneyTests.span / max(width * 0.8, 1)).rounded(.up)))
        let before = adjProbeCount(photo)
        let velocity = XCUIGestureVelocity(PhotoPerfJourneyTests.speed * (NSScreen.main?.backingScaleFactor ?? 1))
        var seconds = 0.0
        for leg in 0..<legs {
            let from: CGFloat = leg.isMultiple(of: 2) ? 0.1 : 0.9
            let started = Date()
            slider.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.5)).click(
                forDuration: 0.05, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 1 - from, dy: 0.5)),
                withVelocity: velocity, thenHoldForDuration: 0.05)
            seconds += Date().timeIntervalSince(started) - PhotoPerfJourneyTests.legPause
        }
        adjExpect("Undo Exposure", photo, "scrubbing the adjustment layer's Exposure made no Exposure step")
        photo.shot("perf-adjustment-layer-exposure")

        let after = adjProbeCount(photo)
        let added = (after?.count ?? 0) - (before?.count ?? 0)
        let series: PhotoPerfJourneyTests.Series
        if let after, added > 0 {
            series = .init(name: "adjustment-layer", samples: added, p95: "\(after.p95FramesLate)", source: "suite.perf bar-slider samples")
        } else {
            let time = String(format: "%.2f", seconds)
            series = .init(
                name: "adjustment-layer", samples: Int((max(seconds, 0) * PhotoPerfJourneyTests.eventRate).rounded(.down)),
                p95: "n/a",
                source: "event samples: \(time) s of drag at 60 Hz; Photo publishes no suite.perf until FrameProbe #330 is wired")
        }
        let line = "QB-L2 PJ-P2 \(series.name): samples=\(series.samples) frames-late-p95=\(series.p95) report-only (\(series.source))"
        print(line)
        // This file is UITests/PhotoJourneyTests+PerfAdjustmentLayers.swift, so its grandparent is the repo root.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appending(path: ".build/ui-screens")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? Data((line + "\n").utf8).write(to: folder.appending(path: "photo-perf-adjustment-layer-scrub.txt"))
        if let json = try? JSONEncoder().encode([line]) {
            let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
            attachment.name = "perf-report-adjustment-layer-scrub"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertGreaterThanOrEqual(
            series.samples, Journey.minimumSamples,
            "PJ-P2 \(series.name) has \(series.samples) samples, under \(Journey.minimumSamples): its numbers mean nothing")
    }

    /// The `suite.perf` summary of `bar-slider`; nil when the window doesn't publish the probe.
    @MainActor private func adjProbeCount(_ photo: Journey) -> ProbeSummary? {
        let element = photo.element("suite.perf")
        guard element.exists,
            let document = try? JSONDecoder().decode(ProbeDocument.self, from: Data(element.label.utf8))
        else { return nil }
        return document.latency["bar-slider"]
    }
}
