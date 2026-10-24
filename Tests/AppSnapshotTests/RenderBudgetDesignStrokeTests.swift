// RenderBudgetDesignStrokeTests.swift (stroke-style DK-4): what a stroke width scrub costs Design's real window.
// `cards` opened with B (node-3) stroked 2 pt (DesignStrokeSeed) and B selected, in a 1280 x 1200 window tall
// enough that the inspector's Stroke rows sit on screen unscrolled. A 120-sample drag across the Width row
// (`suite.stroke.width`) with the canvas live previews on the window's live box and lands at mouse-up, so it runs
// the window body at least once (a drag that changed nothing fails) and at most 3 times. The p95 (8 ms in the
// packet) is printed, not gated: a step-time budget belongs in a Tests/perf-suites.txt test. The test process is
// never the active app, so the root opts in to activation clicks. Nested in BodyCountSuites, as every suite that
// reads a body counter is. macOS debug builds only: the body counters exist only there.
#if canImport(AppKit) && DEBUG
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignStrokeTests {
        @Test(.timeLimit(.minutes(2))) func widthScrubInThreeBodies() async throws {
            let id = "suite.stroke.width"
            let window = DesignWindow(seed: DesignStrokeSeed.cards(selecting: "node-3"), live: DesignLiveDrag())
                .allowsWindowActivationEvents()
            let w = RenderBudgetWindow(window, size: CGSize(width: 1280, height: 1200))
            defer { w.close() }
            try await w.settle(800)
            let box = try #require(await w.element(id), "no \(id)")
            try await w.settle(untilStable: { DesignWindow.bodyRuns + DesignEditor.bodyRuns })
            let start = CGPoint(x: box.midX, y: box.midY)
            // A control below the window's edge would take the drag nowhere and pass on zero cost.
            #expect(w.host.bounds.insetBy(dx: 0, dy: box.height / 2).contains(start), "\(id) at \(box) is off the window")
            let step = try await w.measure("design stroke width scrub", bodies: DesignWindowDragTests.editorBodies) {
                try await w.drag(from: start) { CGPoint(x: start.x + Double($0) / 2, y: start.y) }
            }
            #expect((step.bodies ?? 0) >= 1, "\(id)'s scrub landed no edit")
            expectBodies(step, atMost: 3, target: 3)
        }
    }
}
#endif
