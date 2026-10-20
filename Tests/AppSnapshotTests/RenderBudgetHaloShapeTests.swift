// RenderBudgetHaloShapeTests.swift: the star tool's drag on Halo's real
// window (Tests/render-budgets.md), through the harness
// (RenderBudgetHarness.swift), as RenderBudgetHaloTests drags a layer. On
// `three-layers` with the shape tool on (`HaloWindow(model:shapes:)`, the
// star picked) it drags 120 samples across the viewer: the draft redraws on
// its own, so the window body runs only for the release's draw. `timing`
// judges the step time (report-only once Tests/perf-suites.txt lists it).
// Nested in BodyCountSuites, as every suite that reads a body counter is.
// macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SuiteKernel
import SwiftUI
import Testing

@testable import HaloApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloShapeTests {
        @Test(.timeLimit(.minutes(2))) func starDragInThreeBodies() async throws {
            let (step, drafts) = try await Self.run()
            #expect(drafts >= 100, "the draft didn't follow the drag: \(drafts) of 120 samples")
            // A draft sample is presentation only; the release is one model change. Target: 1.
            expectBodies(step, atMost: 3, target: 1)
        }

        @Test(.timeLimit(.minutes(2))) func starDragTiming() async throws {
            let (step, _) = try await Self.run()
            // Target: a step fits one 120 Hz frame (8.3 ms).
            expectP95(step, atMost: 16, target: 8.3)
        }

        /// Drags a star from composition (760, 340) to (1160, 740), 120 samples; the step and how many samples
        /// showed a draft.
        static func run() async throws -> (step: RenderStep, drafts: Int) {
            let project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
            let shapes = HaloShapeDrawing(tool: ShapeSpec(kind: .star, points: 6, innerRatio: 0.5))
            shapes.isOn = true
            let w = RenderBudgetWindow(
                HaloWindow(model: project, shapes: shapes).environment(\.haloViewerTakesActivationClicks, true))
            defer { w.close() }
            try await w.settle(500)
            let canvas = try #require(await w.element("halo.viewer.canvas"), "no halo.viewer.canvas")
            let size = CGSize(width: 1920, height: 1080)
            let start = w.point(CGPoint(x: 760, y: 340), on: size, in: canvas)
            let end = w.point(CGPoint(x: 1160, y: 740), on: size, in: canvas)
            var drafts = 0
            let step = try await w.measure("halo star drag, 120 samples", bodies: HaloWindowPlaybackTests.windowBodies) {
                try await w.drag(from: start) { i in
                    if shapes.draft != nil { drafts += 1 }
                    let t = Double(i) / 120
                    return CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
                }
            }
            #expect(shapes.draft == nil, "the release left a draft: \(step)")
            return (step, drafts)
        }
    }
}
#endif
