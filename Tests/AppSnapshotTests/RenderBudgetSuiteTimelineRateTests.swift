// RenderBudgetSuiteTimelineRateTests.swift (frame-rates FR-u, FR-6's render
// budget row and FR-5's screen). The gallery's `timeline-long` page at 29.97
// fps in a 1280 x 820 window: a ruler press and 120 drag samples at 120 Hz
// run the page's body at most 3 times (the playhead, log and timecode readout
// live in a feed only their reader views observe), and the readout ends on
// the drop-frame timecode of the last frame scrubbed. The step p95 is printed
// as the readout update's cost, reported and not gated. The press is a
// window-activation click, so the page opts in (RenderBudgetHarness.swift).
// The snapshot is the same page at 29.97 with the playhead at 1800
// (suite-gallery-timeline-2997-{light,dark}.png): the menu's title reads
// "29.97 fps" and the readout "00:01:00;02"; a snapshot can't hold an open
// menu, so the journey's `timeline-2997-menu` shot shows it open. Nested in
// BodyCountSuites: it reads global body counters. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

/// `timeline-long` at 29.97 fps, its playhead at `playhead`.
@MainActor private func ntscFixture(playhead: Int) -> GalleryTimelineFixture {
    var fixture = GalleryTimelineFixture.long
    fixture.rate = FrameRate(numerator: 30_000, denominator: 1_001)
    fixture.playhead = playhead
    return fixture
}

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetSuiteTimelineRateTests {
        @Test(.timeLimit(.minutes(2))) func scrubAt2997() async throws {
            let fixture = ntscFixture(playhead: 120)
            let w = RenderBudgetWindow(GalleryTimelinePage(fixture: fixture).allowsWindowActivationEvents())
            defer { w.close() }
            try await w.settle(600)
            let pageBodies = { () -> Int? in
                #if DEBUG
                return GalleryTimelinePage.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: pageBodies)
            let ruler = try #require(await w.element("suite.timeline.ruler"), "no ruler (suite.timeline.ruler)")
            let start = CGPoint(x: ruler.minX + 40, y: ruler.midY)
            let step = try await w.measure("timeline-long scrub at 29.97", bodies: pageBodies) {
                try await w.drag(from: start, by: CGVector(dx: 480, dy: 0), samples: 120)
            }
            expectBodies(step, atMost: 3, target: 1)
            let last = try #require(
                w.label("suite.gallery.log")?.split(separator: "\n").last.map(String.init), "the page logged nothing")
            let frame = try #require(Int(last.dropFirst("scrub ".count)), "the drag logged \(last), not a scrub")
            let rate = try #require(fixture.rate)
            #expect(w.label("suite.gallery.timeline.timecode") == Timecode.string(frame: frame, rate: rate))
            #expect(w.label("suite.gallery.timeline.timecode")?.contains(";") == true, "29.97 reads non-drop timecode")
        }
    }
}

@MainActor @Suite struct SuiteTimelineRateSnapshots {
    @Test func timelineAt2997() throws {
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(
                GalleryTimelinePage(fixture: ntscFixture(playhead: 1_800)),
                name: "suite-gallery-timeline-2997-\(suffix)", scheme: scheme)
        }
    }
}
#endif
