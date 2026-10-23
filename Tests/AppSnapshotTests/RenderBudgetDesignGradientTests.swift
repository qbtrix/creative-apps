// RenderBudgetDesignGradientTests.swift (gradient-fill DG-6): what a gradient edit costs Design's real window.
// `cards` opened with A (node-2) on DesignGradientSeed's linear gradient and A selected, in a 1280 x 1200 window
// tall enough that the inspector's Fill rows sit on screen unscrolled (a control off the window took the drag
// nowhere and passed on zero cost). A 120-sample drag of the first stop (`suite.gradient.stop.0`) and one across
// the Angle bar (`suite.gradient.angle`) each preview on the window's live box and land at mouse-up, so each runs
// the window body at least once (the landing: a drag that changed nothing fails) and at most 3 times. The p95 is
// printed, not gated: a step-time budget belongs in a Tests/perf-suites.txt test. The window settles until its
// bodies stop running before the drag starts. The test process is never the active app, so the root opts in to
// activation clicks. Nested in BodyCountSuites, as every suite that reads a body counter is. macOS debug builds
// only: the body counters exist only there.
#if canImport(AppKit) && DEBUG
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignGradientTests {
        @Test(.timeLimit(.minutes(2))) func stopDragInThreeBodies() async throws {
            try await Self.drag("suite.gradient.stop.0", name: "design gradient stop drag") { Double($0) / 2 }
        }

        @Test(.timeLimit(.minutes(2))) func angleScrubInThreeBodies() async throws {
            try await Self.drag("suite.gradient.angle", name: "design gradient angle scrub") { Double($0) }
        }

        /// Drags the control `id` from its middle by `dx(i)` over 120 samples and gates the window's bodies.
        static func drag(_ id: String, name: String, dx: (Int) -> Double) async throws {
            let seed = DesignGradientSeed.cards(selecting: "node-2")
            // Tall enough that the Fill rows sit inside the window without scrolling the inspector.
            let window = DesignWindow(seed: seed, live: DesignLiveDrag()).allowsWindowActivationEvents()
            let w = RenderBudgetWindow(window, size: CGSize(width: 1280, height: 1200))
            defer { w.close() }
            try await w.settle(800)
            let box = try #require(await w.element(id), "no \(id)")
            try await w.settle(untilStable: { DesignWindow.bodyRuns + DesignEditor.bodyRuns })
            let start = CGPoint(x: box.midX, y: box.midY)
            // A control below the window's edge would take the drag nowhere and pass on zero cost.
            #expect(w.host.bounds.insetBy(dx: 0, dy: box.height / 2).contains(start), "\(id) at \(box) is off the window")
            let step = try await w.measure(name, bodies: DesignWindowDragTests.editorBodies) {
                try await w.drag(from: start) { CGPoint(x: start.x + dx($0), y: start.y) }
            }
            #expect((step.bodies ?? 0) >= 1, "\(id)'s drag landed no edit")
            expectBodies(step, atMost: 3, target: 3)
        }
    }
}
#endif
