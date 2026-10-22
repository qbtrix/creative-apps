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
// menu, so the journey's `timeline-2997-menu` shot shows it open; it draws
// half a point a frame, as a snapshot can't scroll, so 1800 is in view. The
// layout tests lay the page out at 1280 x 820 and 900 x 612, live and as a
// snapshot draws it: the log sits below the strip inside the page's margin
// and no lane name draws over it (#4364), and the live strip opens on the
// playhead's page, its pill clear of the ruler's trailing edge (#4365).
// Nested in BodyCountSuites: it reads global body counters. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

/// `timeline-long` at 29.97 fps, its playhead at `playhead`.
@MainActor private func ntscFixture(playhead: Int, frameWidth: CGFloat? = nil) -> GalleryTimelineFixture {
    var fixture = GalleryTimelineFixture.long
    fixture.rate = FrameRate(numerator: 30_000, denominator: 1_001)
    fixture.playhead = playhead
    if let frameWidth { fixture.frameWidth = frameWidth }
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

        /// #4364: the log keeps its line below the strip, inside the page's margin, live and as a snapshot.
        @Test(.timeLimit(.minutes(2)), arguments: [CGSize(width: 1_280, height: 820), CGSize(width: 900, height: 612)])
        func logSitsBelowTheStrip(size: CGSize) async throws {
            for snapshot in [false, true] {
                let page = GalleryTimelinePage(fixture: ntscFixture(playhead: 1_800))
                    .environment(\.suiteSnapshotRendering, snapshot)
                let w = RenderBudgetWindow(page, size: size)
                defer { w.close() }
                try await w.settle(600)
                let mode = snapshot ? "snapshot" : "live"
                let strip = try #require(await w.element("suite.gallery.timeline.strip"), "no strip (\(mode))")
                let log = try #require(await w.element("suite.gallery.log"), "no log (\(mode))")
                // Window coordinates, y up: below the strip is a smaller y.
                #expect(log.height > 0, "the log has no height at \(size) (\(mode))")
                #expect(log.maxY <= strip.minY + 0.5, "the log \(log) runs into the strip \(strip) at \(size) (\(mode))")
                let content = CGRect(origin: .zero, size: size).insetBy(dx: SuiteSpacing.m, dy: SuiteSpacing.m)
                #expect(content.insetBy(dx: -0.5, dy: -0.5).contains(log), "the log \(log) leaves the page's margin (\(mode))")
                for row in 0..<40 {
                    guard let name = await w.element("suite.timeline.name.lane-\(row)") else { continue }
                    // The strip clips its lanes: only the part of a name inside it draws.
                    let drawn = name.intersection(strip)
                    #expect(drawn.isNull || !drawn.intersects(log), "lane \(row)'s name draws over the log (\(mode))")
                }
            }
        }

        /// #4365: a live strip opens scrolled to the playhead's page, its pill clear of the ruler's end.
        @Test(.timeLimit(.minutes(2))) func playheadAt1800IsInView() async throws {
            let w = RenderBudgetWindow(GalleryTimelinePage(fixture: ntscFixture(playhead: 1_800)))
            defer { w.close() }
            try await w.settle(800)
            let ruler = try #require(await w.element("suite.timeline.ruler"), "no ruler (suite.timeline.ruler)")
            let pill = try #require(await w.element("suite.timeline.playhead"), "no pill (suite.timeline.playhead)")
            #expect(pill.midX > ruler.minX, "the pill \(pill) is left of the ruler \(ruler)")
            #expect(pill.midX < ruler.maxX - pill.width / 2, "the pill \(pill) is pinned at the ruler's end \(ruler)")
            #expect(pill.intersects(ruler), "the pill \(pill) is off the ruler \(ruler)")
        }
    }
}

@MainActor @Suite struct SuiteTimelineRateSnapshots {
    @Test func timelineAt2997() throws {
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(
                GalleryTimelinePage(fixture: ntscFixture(playhead: 1_800, frameWidth: 0.5)),
                name: "suite-gallery-timeline-2997-\(suffix)", scheme: scheme)
        }
    }
}
#endif
