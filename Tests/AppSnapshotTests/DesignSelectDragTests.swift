// DesignSelectDragTests.swift: select-several S-6's bound on the real window. On
// `crowd` (2,000 layers), a 120-sample marquee and a 120-sample resize of the
// several-layer box each run DesignEditor's body 3 times or fewer: the samples
// go to the live drag box (DesignLiveDrag), which only the canvas reads. The
// marquee is design-window D0-8b's `dragSamples(.marquee)`; the resize selects
// Frame 1 and Frame 2 and drags their box's bottom-right handle, which the
// canvas gesture routes to the several-layer resize. Nested in BodyCountSuites,
// as DesignEditor.bodyRuns is a process-global debug counter. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct DesignSelectDragTests {
        typealias Drag = DesignWindowDragTests

        @Test(.timeLimit(.minutes(3))) func aMarqueeRunsTheEditorAtMostThreeTimes() async throws {
            #if DEBUG
            let w = RenderBudgetWindow(DesignWindow(seed: Drag.Gesture.marquee.seed))
            defer { w.close() }
            let step = try await Drag.dragSamples(.marquee, in: w)
            #expect((step.bodies ?? 0) >= 1, "the marquee never reached the window: \(step)")
            expectBodies(step, atMost: 3, target: 3)
            #endif
        }

        @Test(.timeLimit(.minutes(3))) func aSeveralLayerResizeRunsTheEditorAtMostThreeTimes() async throws {
            #if DEBUG
            // Frame 1 (node-1) at (10, 10, 160 × 150) and Frame 2 (node-51) at (185, 10, 160 × 150):
            // their box is (10, 10)–(345, 160), its bottom-right handle at (345, 160).
            var seed = DesignFixtures.crowd
            seed.selectItem("node-1")
            seed.toggleSelection("node-51")
            try #require(seed.selectedNodeIDs == ["node-1", "node-51"])
            try #require(seed.selectionBounds == DesignRect(x: 10, y: 10, width: 335, height: 150))
            try #require(seed.transformHelp == nil)
            let w = RenderBudgetWindow(DesignWindow(seed: seed))
            defer { w.close() }
            try await w.settle(800)
            let board = try #require(await w.element("suite.canvas"), "no canvas")
            let start = w.point(CGPoint(x: 345, y: 160), on: Drag.page, in: board)
            let end = w.point(CGPoint(x: 465, y: 240), on: Drag.page, in: board)
            let step = try await w.measure("design several-layer resize, 120 samples", bodies: Drag.editorBodies) {
                try await w.drag(from: start, by: CGVector(dx: end.x - start.x, dy: end.y - start.y))
            }
            #expect((step.bodies ?? 0) >= 1, "the resize never reached the window: \(step)")
            expectBodies(step, atMost: 3, target: 3)
            #endif
        }
    }
}
#endif
