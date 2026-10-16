// RenderBudgetHaloTests.swift: Halo's render budget (Tests/render-budgets.md)
// on the real window, through the harness (RenderBudgetHarness.swift). On
// `-HaloSample keyed` it clicks Ball's row in the layer list, drags the
// inspector's divider with Ball selected (its layer inspector showing), then
// drags Floor 120 samples in the viewer (the window takes the test's
// window-activation clicks there, `haloViewerTakesActivationClicks`);
// HaloWindowPlaybackTests plays one second. `bodies` gates the window-body
// counts; `timing` (Tests/perf-suites.txt, report-only) judges the step times
// with 120 divider samples. Nested in BodyCountSuites, as every suite that
// reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloTests {
        @Test(.timeLimit(.minutes(3))) func bodies() async throws {
            let (select, divider, viewer) = try await Self.run(dividerSamples: 12)
            // Selecting a layer is one model change: one body. Target: 1.
            expectBodies(select, atMost: 1, target: 1)  // dev: 1
            // A divider drag is presentation only. Target: 0.
            expectBodies(divider, atMost: 0, target: 0)  // dev: 0
            // A viewer drag: the window runs at most 3 times (HaloWindowLiveDragTests' bound). Target: 3.
            expectBodies(viewer, atMost: 3, target: 3)  // dev: 2
        }

        @Test(.timeLimit(.minutes(6))) func timing() async throws {
            let (select, divider, viewer) = try await Self.run(dividerSamples: 120)
            let (playback, _, _, _) = try await HaloWindowPlaybackTests.playOneSecond()
            // Targets: a step fits one 120 Hz frame (8.3 ms); selecting may take two 60 Hz frames.
            expectP95(select, atMost: 130, target: 33)  // dev: 108 ms
            expectP95(divider, atMost: 130, target: 8.3)  // dev: 97 ms
            expectP95(viewer, atMost: 4, target: 8.3)  // dev: 2.9 ms
            expectP95(playback, atMost: 27, target: 8.3)  // dev: 17.0 ms
        }

        /// Select Ball, drag the inspector divider `dividerSamples` steps with Ball selected, then drag Floor
        /// across the viewer.
        static func run(dividerSamples: Int) async throws -> (select: RenderStep, divider: RenderStep, viewer: RenderStep) {
            let project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            let w = RenderBudgetWindow(HaloWindow(model: project).environment(\.haloViewerTakesActivationClicks, true))
            defer { w.close() }
            try await w.settle(500)
            let ball = try #require(await w.element("halo.layer.row.comp-1-layer-2"), "no Ball row in the layer list")
            let select = try await w.measure("halo select a layer", bodies: HaloWindowPlaybackTests.windowBodies) {
                try await w.ticks(1) { _ in w.click(at: CGPoint(x: ball.midX, y: ball.midY)) }
            }
            let shown = await w.element("halo.layer.row.comp-1-layer-2") != nil
            #expect(shown && (select.bodies ?? 1) >= 1, "the click didn't select Ball: \(select)")
            let inspector = try #require(await w.splitViews().last, "no inspector split view")
            var moved: (before: CGFloat, after: CGFloat) = (0, 0)
            let divider = try await w.measure(
                "halo inspector divider drag, Ball selected", bodies: HaloWindowPlaybackTests.windowBodies
            ) {
                moved = try await w.dragDivider(0, of: inspector, by: -120, samples: dividerSamples)
            }
            #expect(moved.after > moved.before, "the inspector divider never moved: \(moved)")
            try await w.settle()
            // Composition (960, 980) is the middle of Floor's band, under nothing else at frame 0.
            let canvas = try #require(await w.element("halo.viewer.canvas"), "no halo.viewer.canvas")
            let start = w.point(CGPoint(x: 960, y: 980), on: CGSize(width: 1920, height: 1080), in: canvas)
            #if DEBUG
            let undos = HaloWindow.shownProject?.history.undo.count
            #endif
            let viewer = try await w.measure("halo viewer drag, 120 samples", bodies: HaloWindowPlaybackTests.windowBodies) {
                try await w.drag(from: start, by: CGVector(dx: 120, dy: 30))
            }
            #if DEBUG
            #expect(
                HaloWindow.shownProject?.history.undo.count == undos.map { $0 + 1 },
                "the viewer drag didn't land as one step: \(viewer)")
            #endif
            return (select, divider, viewer)
        }
    }
}
#endif
