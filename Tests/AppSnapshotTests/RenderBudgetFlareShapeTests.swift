// RenderBudgetFlareShapeTests.swift: the Shape tool's render budget (shape-tools FS-4, Tests/render-budgets.md) on
// the real window, through the harness (RenderBudgetHarness.swift). On New Sample Animation with the Shape tool on
// its default star, it drags 120 samples across the canvas: the samples run on the stage's FlareLiveDrag, whose
// draft is the kernel's star path, so the window's body runs only for the drag's end at mouse-up, never per sample.
// The draw itself waits on shape-tools FS-6, so mouse-up adds no layer yet. `starDragInThreeBodies` gates the
// window-body count; `timing` judges the step times against the packet's 8 ms and is report-only: it stays disabled
// until Tests/perf-suites.txt lists it (only the supervisor edits that list). Nested in BodyCountSuites, as every
// suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import FlareModel
import SwiftUI
import Testing

@testable import FlareApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetFlareShapeTests {
        @Test(.timeLimit(.minutes(2))) func starDragInThreeBodies() async throws {
            let drag = try await Self.run()
            // The star drafts on the stage's live copy; the window runs for the drag's end at most. Target: 3.
            expectBodies(drag, atMost: 3, target: 3)
        }

        @Test(.disabled("report-only: enable once Tests/perf-suites.txt lists it"), .timeLimit(.minutes(2)))
        func timing() async throws {
            let drag = try await Self.run()
            // Target: a step fits the packet's 8 ms (one 120 Hz frame).
            expectP95(drag, atMost: 20, target: 8)  // not measured yet
        }

        static func run() async throws -> RenderStep {
            var model = FlareWorkspace(services: .built)
            model.newSampleAnimation()
            model.selectTool(.shape)
            #expect(model.shapeTool.kind == .star)
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
            #if DEBUG
            let before = FlareWindow.shownModel?.selectedScene?.layers.count ?? 0
            #endif
            let drag = try await w.measure("flare canvas star drag", bodies: bodies) {
                try await w.drag(from: CGPoint(x: 600, y: 420), by: CGVector(dx: 200, dy: 80))
            }
            try await w.settle(100)
            #if DEBUG
            let after = FlareWindow.shownModel?.selectedScene?.layers.count ?? 0
            #expect(after == before, "the star drag drew before shape-tools FS-6: \(drag)")
            #endif
            return drag
        }
    }
}
#endif
