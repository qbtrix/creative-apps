// RenderBudgetHaloTests.swift: Halo's render budget (Tests/render-budgets.md)
// on the real window, through the harness (RenderBudgetHarness.swift). On
// `-HaloSample keyed` it clicks Ball's row in the layer list, then drags the
// inspector's divider with Ball selected (its layer inspector showing);
// HaloWindowPlaybackTests plays one second. `bodies` gates the window-body
// counts; `timing` (Tests/perf-suites.txt, report-only) judges the step times
// with 120 divider samples. A drag in the viewer isn't driven yet: the viewer
// ignores the test's window-activation clicks until perf/halo-live-drag's
// `haloViewerTakesActivationClicks` lands. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor @Suite(.serialized) struct RenderBudgetHaloTests {
    @Test(.timeLimit(.minutes(3))) func bodies() async throws {
        let (select, divider) = try await Self.run(dividerSamples: 12)
        // Selecting a layer is one model change: one body. Target: 1.
        expectBodies(select, atMost: 2, target: 1)  // dev: 1
        // A divider drag is presentation only. Target: 0.
        expectBodies(divider, atMost: 1, target: 0)  // dev: 0
    }

    @Test(.timeLimit(.minutes(6))) func timing() async throws {
        let (select, divider) = try await Self.run(dividerSamples: 120)
        let (playback, _) = try await BodyCountSuites.HaloWindowPlaybackTests.playOneSecond()
        // Targets: a step fits one 120 Hz frame (8.3 ms); selecting may take two 60 Hz frames.
        expectP95(select, atMost: 1500, target: 33)  // dev: 1018 ms
        expectP95(divider, atMost: 1500, target: 8.3)  // dev: 1057 ms
        expectP95(playback, atMost: 27, target: 8.3)  // dev: 17.9 ms
    }

    /// Select Ball, then drag the inspector divider `dividerSamples` steps with Ball selected.
    static func run(dividerSamples: Int) async throws -> (select: RenderStep, divider: RenderStep) {
        let project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
        let w = RenderBudgetWindow(HaloWindow(model: project))
        defer { w.close() }
        try await w.settle(500)
        let ball = try #require(await w.element("halo.layer.row.comp-1-layer-2"), "no Ball row in the layer list")
        let select = try await w.measure("halo select a layer", bodies: BodyCountSuites.HaloWindowPlaybackTests.windowBodies) {
            try await w.ticks(1) { _ in w.click(at: CGPoint(x: ball.midX, y: ball.midY)) }
        }
        let shown = await w.element("halo.layer.row.comp-1-layer-2") != nil
        #expect(shown && (select.bodies ?? 1) >= 1, "the click didn't select Ball: \(select)")
        let inspector = try #require(await w.splitViews().last, "no inspector split view")
        var moved: (before: CGFloat, after: CGFloat) = (0, 0)
        let divider = try await w.measure(
            "halo inspector divider drag, Ball selected", bodies: BodyCountSuites.HaloWindowPlaybackTests.windowBodies
        ) {
            moved = try await w.dragDivider(0, of: inspector, by: -120, samples: dividerSamples)
        }
        #expect(moved.after > moved.before, "the inspector divider never moved: \(moved)")
        return (select, divider)
    }
}
#endif
