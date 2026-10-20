// HaloJourneyTests+Perf.swift: Halo's perf journeys H-P1 to H-P5 (packet
// docs/blueprints/halo/features/core-loop.md, Journey steps and Quality
// tests; blueprint halo 7.1, HB-U1 to HB-U4 and QB-L10's UI half). Each
// journey launches with `-SuitePerfProbe` and ends with `perf()`
// (Journey+Input.swift), which attaches "perf-<test>" and checks the gates
// below through `PerfBudgeted`. Every gate is report-only: `limit` is 7.1's
// CI placeholder and `enforced` stays false until ten green runs on `dev`.
// CL-3 adds the class with every test skipped; CL-10 replaces each skip with
// its journey once the window records the series (CL-8, the probe sites).
import XCTest

final class HaloPerfJourneyTests: XCTestCase {
    /// H-P1, `reference`: four 600 pt viewer drags at 300 pt/s on
    /// `halo.viewer.canvas`; series `viewer-drag` (HB-U1).
    @MainActor func testViewerDragLatency() throws {
        throw XCTSkip("waits on CL-10")
    }

    /// H-P2, `reference`: a velocity drag across the rotation row's bar;
    /// series `inspector-scrub` (HB-U2).
    @MainActor func testInspectorScrubLatency() throws {
        throw XCTSkip("waits on CL-10")
    }

    /// H-P3, `reference`: a velocity drag on `halo.timeline` from dx 0.02 to
    /// 0.98 at dy 0.05; series `playhead-scrub` (HB-U3).
    @MainActor func testPlayheadScrubLatency() throws {
        throw XCTSkip("waits on CL-10")
    }

    /// H-P4, `reference`: Play, 5 s, Pause; series `playback`, intervals (HB-U4).
    @MainActor func testPlaybackHoldsRate() throws {
        throw XCTSkip("waits on CL-10")
    }

    /// H-P5, `crowd`: the lanes and the layer list scrolled end to end;
    /// series `lanes-scroll` and `layers-scroll`, intervals (QB-L10).
    @MainActor func testTimelineAndLayerListScroll() throws {
        throw XCTSkip("waits on CL-10")
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
