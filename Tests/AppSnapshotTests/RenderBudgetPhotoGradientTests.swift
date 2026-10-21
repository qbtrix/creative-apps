// RenderBudgetPhotoGradientTests.swift (gradient-fill PG-5, quality row
// "render: 120-sample gradient drag (the line only, pixels on release)"):
// what a Gradient tool drag costs the real Photo window, on the render budget
// harness (RenderBudgetHarness.swift). It hosts PhotoWindow on the `large`
// fixture (4000 x 3000, 12 MP) with the Gradient tool picked and drags 120
// samples at 120 Hz down the canvas, measured until just before the mouse-up,
// as PhotoWindowStrokeTests measures a brush stroke. During the drag the
// canvas shows only the drag's line (PhotoCanvasOverlay) and no pixel
// changes, so PhotoEditor's body (a debug-only counter) runs at most 3 times
// (target 0) and the workspace's revision doesn't move; the gradient's pixels
// land on release. `gradientDragTiming` prints the step p95 (budget 8 ms) and
// asserts nothing on time until the supervisor lists it in
// Tests/perf-suites.txt. Nested in BodyCountSuites, as every suite that reads
// a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoGradientTests {
        @Test(.timeLimit(.minutes(2))) func gradientDragInThreeBodies() async throws {
            let drag = try await Self.run()
            #expect(drag.dragging, "the window's workspace had no gradient drag under way: \(drag.step)")
            #expect(drag.revisions == 0, "the drag changed pixels before its release (\(drag.revisions) revisions)")
            // The line is the overlay's: the editor's body never runs. Budget 3, target 0.
            expectBodies(drag.step, atMost: 3, target: 0)
        }

        @Test(.timeLimit(.minutes(2))) func gradientDragTiming() async throws {
            let drag = try await Self.run()
            // Print-only until the supervisor lists this test in Tests/perf-suites.txt: a step-time
            // assertion in the gate can go red on a loaded runner. Budget p95 8 ms.
            print("RENDER-BUDGET photo gradient drag p95 \(String(format: "%.2f", drag.step.p95)) ms (budget 8, target 8)")
            #expect(drag.dragging, "the window's workspace had no gradient drag under way: \(drag.step)")
        }

        struct Drag {
            let step: RenderStep
            /// Whether the window's workspace held the drag just before the mouse-up.
            let dragging: Bool
            /// How far the workspace's revision moved during the drag.
            let revisions: Int
        }

        /// One 120-sample gradient drag on the hosted window, top to bottom down the canvas's middle,
        /// measured until just before its mouse-up.
        static func run() async throws -> Drag {
            var open = try PhotoWorkspace.fixture(.large)
            open.selectTool(.gradient)
            #expect(open.tool == .gradient, "the Gradient tool couldn't be picked")
            let w = RenderBudgetWindow(PhotoWindow(model: open))
            defer { w.close() }
            let canvas = try #require(await w.first(CanvasHostView.self))
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let bodies = { () -> Int? in BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(untilStable: bodies)
            let before = try #require(edited.workspace)
            let box = canvas.convert(canvas.bounds, to: nil)
            let start = CGPoint(x: box.midX, y: box.minY + box.height * 0.15)
            let path = { (i: Int) in
                CGPoint(x: start.x + 60 * sin(Double(i) / 20), y: start.y + box.height * 0.7 * CGFloat(i) / 120)
            }
            // `measure` lets the drag's last renders land before the mouse comes up.
            let step = try await w.measure("photo gradient drag, 120 samples", bodies: bodies) {
                try await w.drag(from: start, release: false, path: path)
            }
            let during = try #require(edited.workspace)
            w.send(.leftMouseUp, at: path(120))
            try await w.settle()
            return Drag(step: step, dragging: during.isDragging, revisions: during.revision - before.revision)
        }
    }
}
#endif
