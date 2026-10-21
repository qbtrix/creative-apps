// RenderBudgetAreaSelectTests.swift (area-selection AR-8, Quality tests): the gallery's `area-select` page in a
// 1280 x 820 window (RenderBudgetHarness.swift). With the Lasso chosen, a 120-sample circular drag on the area canvas
// (`suite.gallery.area-canvas`) runs `select.lasso` once at mouse-up; with the Wand chosen, one click runs
// `select.wand`. Each runs the window body at most 3 times (the packet's "≤ 3 window bodies"): the page keeps the
// lasso in progress in its own state for the ants, so a sample never reruns the window. The window body is
// AreaBudgetHost's, the root that hosts the page and opts in to activation clicks (the test process is never the
// active app). `timing` judges the packet's p95 ≤ 8 ms and is report-only: it stays disabled until
// Tests/perf-suites.txt lists it (only the supervisor edits that list). Nested in BodyCountSuites: it reads a body
// counter. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetAreaSelectTests {
        @Test(.timeLimit(.minutes(2))) func lassoDragInThreeBodies() async throws {
            let (lasso, wand) = try await Self.run()
            // One select at mouse-up: one log line and one outline. Target: 1.
            expectBodies(lasso, atMost: 3, target: 1)
            expectBodies(wand, atMost: 3, target: 1)
        }

        @Test(.disabled("report-only: enable once Tests/perf-suites.txt lists it"), .timeLimit(.minutes(2)))
        func timing() async throws {
            let (lasso, _) = try await Self.run()
            // Target: a sample fits the packet's 8 ms (one 120 Hz frame).
            expectP95(lasso, atMost: 8, target: 8)
        }

        /// Chooses the Lasso, drags a 120-sample circle on the canvas, then chooses the Wand and clicks inside it;
        /// returns the two measured steps after checking each ran its command.
        private static func run() async throws -> (lasso: RenderStep, wand: RenderStep) {
            let w = RenderBudgetWindow(AreaBudgetHost())
            defer { w.close() }
            try await w.settle(600)
            let bodies = { () -> Int? in AreaBudgetHost.bodyRuns }
            try await choose(.lasso, in: w, bodies: bodies)
            let canvas = try #require(await w.element("suite.gallery.area-canvas"), "no suite.gallery.area-canvas")
            let (center, radius) = (CGPoint(x: canvas.midX, y: canvas.midY), min(canvas.width, canvas.height) * 0.3)
            let start = CGPoint(x: center.x + radius, y: center.y)
            let lasso = try await w.measure("area-select lasso drag, 120 samples", bodies: bodies) {
                try await w.drag(from: start) { i in
                    let angle = 2 * Double.pi * Double(i) / 120
                    return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                }
            }
            let lassoLine = w.label("suite.gallery.log") ?? ""
            #expect(lassoLine.hasPrefix("select.lasso replace") && !lassoLine.contains("refused"),
                    "the lasso drag logged \(lassoLine), not one select.lasso")
            try await choose(.wand, in: w, bodies: bodies)
            let wand = try await w.measure("area-select wand click", bodies: bodies) {
                try await w.ticks(1) { _ in w.click(at: center) }
            }
            let wandLine = w.label("suite.gallery.log") ?? ""
            #expect(wandLine.hasPrefix("select.wand replace") && !wandLine.contains("refused"),
                    "the wand click logged \(wandLine), not one select.wand")
            return (lasso, wand)
        }

        /// Clicks `tool`'s chip on the options bar and settles.
        private static func choose(_ tool: AreaTool, in w: RenderBudgetWindow<AreaBudgetHost>, bodies: () -> Int?) async throws {
            let id = "suite.area.tool-\(tool.rawValue)"
            let chip = try #require(await w.element(id), "no \(id) chip")
            try await w.ticks(1) { _ in w.click(at: CGPoint(x: chip.midX, y: chip.midY)) }
            try await w.settle(untilStable: bodies)
        }
    }
}

/// The window: the gallery's area page, counting its own bodies, the window bodies the budget counts.
private struct AreaBudgetHost: View {
    @MainActor static var bodyRuns = 0

    var body: some View {
        let _ = Self.bodyRuns += 1
        GalleryAreaSelectPage().allowsWindowActivationEvents()
    }
}
#endif
