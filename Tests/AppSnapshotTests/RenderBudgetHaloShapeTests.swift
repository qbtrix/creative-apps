// RenderBudgetHaloShapeTests.swift: a 120-sample star drag on Halo's real
// window (Tests/render-budgets.md); the draft redraws on its own, so the
// window body runs only for the release. macOS only.
#if canImport(AppKit)
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
            expectBodies(step, atMost: 3, target: 1)
        }

        @Test(.timeLimit(.minutes(2))) func starDragTiming() async throws {
            let (step, _) = try await Self.run()
            expectP95(step, atMost: 16, target: 8.3)
        }

        /// A star from composition (760, 340) to (1160, 740); the step and the samples with a draft.
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
                    return CGPoint(x: start.x + (end.x - start.x) * Double(i) / 120, y: start.y + (end.y - start.y) * Double(i) / 120)
                }
            }
            #expect(shapes.draft == nil, "the release left a draft: \(step)")
            return (step, drafts)
        }
    }
}
#endif
