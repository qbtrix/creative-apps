// RenderBudgetFlareTests.swift: Flare's render budget
// (Tests/render-budgets.md) on the real window, through the harness
// (RenderBudgetHarness.swift). On New Sample Animation with Ball's first
// easing segment selected, it steps the easing inspector's X1 scrub row 60
// times through its slider (the way VoiceOver and XCUI adjust it: the row's
// drag ignores the test's window-activation clicks), then with Rectangle
// chosen drags 120 samples across the canvas, which draws a rectangle: the
// samples run on the stage's FlareLiveDrag, so the window's body runs only for
// the commit at mouse-up (#1792). `bodies` gates the window-body counts; `timing`
// (Tests/perf-suites.txt, report-only) judges the step times. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import FlareModel
import SwiftUI
import Testing

@testable import FlareApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetFlareTests {
        @Test(.timeLimit(.minutes(2))) func bodies() async throws {
            let (scrub, canvas) = try await Self.run()
            // Each step is one easing edit: one body. Target: 60.
            expectBodies(scrub, atMost: 60, target: 60)  // dev: 60
            // A Rectangle drag draws on the stage's live copy; the window runs for its start, its end and the
            // commit at most, never per sample. Target: 3.
            expectBodies(canvas, atMost: 3, target: 3)  // dev: 122 before #1792
        }

        @Test(.timeLimit(.minutes(2))) func timing() async throws {
            let (scrub, canvas) = try await Self.run()
            // Target: a step fits one 120 Hz frame.
            expectP95(scrub, atMost: 20, target: 8.3)  // dev: 13.0 ms
            expectP95(canvas, atMost: 20, target: 8.3)  // dev: 54.1 ms before #1792; not re-measured yet
        }

        static func run() async throws -> (scrub: RenderStep, canvas: RenderStep) {
            // The real services, as the app launches on: `FlareWorkspace()` is `.live`, whose stage and shapes are
            // NotBuilt, so its stage list is always empty and a Rectangle drag draws nothing (#1792).
            var model = FlareWorkspace(services: .built)
            model.newSampleAnimation()
            let segment = try #require(model.easingSegments.first, "the sample has no easing segment")
            model.selectEasingSegment(segment)
            model.selectTool(.rectangle)
            let w = RenderBudgetWindow(FlareWindow(model: model))
            defer { w.close() }
            try await w.settle(500)
            let bodies = { () -> Int? in
                #if DEBUG
                return FlareWindow.bodyRuns
                #else
                return nil
                #endif
            }
            var found = false
            let scrub = try await w.measure("flare scrub row X1, 60 steps", bodies: bodies) {
                found = try await w.adjust("flare.easing.row.x1", steps: 60)
            }
            #expect(found && (scrub.bodies ?? 1) >= 1, "the X1 row didn't step: \(scrub)")
            #if DEBUG
            let before = FlareWindow.shownModel?.stageList?.items.count ?? 0
            #endif
            let canvas = try await w.measure("flare canvas rectangle drag", bodies: bodies) {
                try await w.drag(from: CGPoint(x: 600, y: 420), by: CGVector(dx: 200, dy: 80))
            }
            try await w.settle(100)
            #if DEBUG
            let after = FlareWindow.shownModel?.stageList?.items.count ?? 0
            #expect(after == before + 1, "the canvas drag drew no rectangle: \(canvas)")
            #endif
            return (scrub, canvas)
        }
    }
}
#endif
