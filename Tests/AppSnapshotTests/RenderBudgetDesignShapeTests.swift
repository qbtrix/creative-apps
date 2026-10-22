// RenderBudgetDesignShapeTests.swift (shape-tools DS-4): what a star costs Design's real window. `cards` with
// C (node-4) a five-point star at 700, 100, 200 × 200, selected (DesignShapeSeed), the canvas live
// (DesignLiveDrag). `starDragInThreeBodies` presses the star's bottom-right handle (900, 300) and drags it 120
// samples out and down, so every sample redraws the star's path in its new frame. It runs the window body at
// most 3 times, with p95 within 8 ms (reported). The resize changes the window's live copy (DesignLiveDrag) and
// lands once at the end, so the samples redraw the canvas, not the window. The window settles until its bodies
// stop running before the drag starts. The test process is never the active app, so the root opts in to
// activation clicks. Nested in BodyCountSuites, as every suite that reads a body counter is. macOS debug builds
// only: the body counters exist only there.
#if canImport(AppKit) && DEBUG
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignShapeTests {
        static let page = CGSize(width: 1440, height: 1024)

        @Test(.timeLimit(.minutes(2))) func starDragInThreeBodies() async throws {
            let seed = DesignShapeSeed.star
            #expect(seed.selectedNode?.shape?.kind == .star)
            let w = RenderBudgetWindow(DesignWindow(seed: seed, live: DesignLiveDrag()).allowsWindowActivationEvents())
            defer { w.close() }
            try await w.settle(800)
            _ = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            try await w.settle(untilStable: { DesignWindow.bodyRuns + DesignEditor.bodyRuns })
            let board = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            // The bottom-right handle sits on the star's box corner, (900, 300) in page points.
            let at = { (i: Int) -> CGPoint in
                w.point(CGPoint(x: 900 + Double(i), y: 300 + Double(i) / 2), on: Self.page, in: board)
            }
            let step = try await w.measure("design shape star drag, 120 samples", bodies: { DesignWindow.bodyRuns }) {
                try await w.drag(from: at(0), path: at)
            }
            #expect(step.steps >= 120, "the drag sent \(step.steps) steps")
            expectBodies(step, atMost: 3, target: 3)
            expectP95(step, atMost: 8, target: 4)
        }
    }
}
#endif
