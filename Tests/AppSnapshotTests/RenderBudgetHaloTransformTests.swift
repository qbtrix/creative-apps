// RenderBudgetHaloTransformTests.swift: the transform handles' render budget
// (transform HT-4, Tests/render-budgets.md) on the real Halo window through
// the harness (RenderBudgetHarness.swift). On `-HaloSample keyed` (1080p,
// paused) it clicks Ball's row in the layer list, finds the handles' rotate
// knob (`suite.handles.turn`) and drags it 120 samples round Ball's centre.
// Budget: the window's body runs at most 3 times; each sample shows through
// HaloLiveEdit and the release commits once. The packet's p95 ≤ 16 ms is
// printed with the step, not gated: a timing gate belongs in
// Tests/perf-suites.txt, which only the supervisor edits. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloTransformTests {
        @Test(.timeLimit(.minutes(3))) func knobDragInThreeBodies() async throws {
            let project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            let w = RenderBudgetWindow(HaloWindow(model: project).environment(\.haloViewerTakesActivationClicks, true))
            defer { w.close() }
            try await w.settle(500)
            let row = try #require(await w.element("halo.layer.row.comp-1-layer-2"), "no Ball row in the layer list")
            try await w.ticks(1) { _ in w.click(at: CGPoint(x: row.midX, y: row.midY)) }
            try await w.settle()
            let knob = try #require(await w.element("suite.handles.turn"), "no rotate knob on Ball's handles")
            let canvas = try #require(await w.element("halo.viewer.canvas"), "no halo.viewer.canvas")
            // A quarter circle from the knob round the canvas's middle: every sample moves off the press, so
            // the knob turns Ball by some amount on each.
            let start = CGPoint(x: knob.midX, y: knob.midY)
            let centre = CGPoint(x: canvas.midX, y: canvas.midY)
            let (dx, dy) = (Double(start.x - centre.x), Double(start.y - centre.y))
            let radius = max((dx * dx + dy * dy).squareRoot(), 40)
            let from = atan2(dy, dx)
            let step = try await w.measure(
                "halo transform knob drag, 120 samples", bodies: HaloWindowPlaybackTests.windowBodies
            ) {
                try await w.drag(from: start) { i in
                    let a = from - (Double.pi / 2) * Double(i) / 120
                    return CGPoint(x: Double(centre.x) + radius * cos(a), y: Double(centre.y) + radius * sin(a))
                }
            }
            print("TRANSFORM-KNOB \(step) | packet budget: p95 ≤ 16 ms (measured \(step.p95) ms)")
            #expect(step.steps >= 120, "the drag sent \(step.steps) steps")
            // Target: 3 (the release's one commit, plus the live preview's start and end).
            expectBodies(step, atMost: 3, target: 3)
        }
    }
}
#endif
