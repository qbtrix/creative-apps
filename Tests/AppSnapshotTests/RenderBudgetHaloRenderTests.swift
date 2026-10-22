// RenderBudgetHaloRenderTests.swift: the render sheet's render budget
// (Tests/render-budgets.md; packet docs/blueprints/halo/features/core-loop.md,
// Quality tests) on the real window, through the harness
// (RenderBudgetHarness.swift). Opening File > Render… (the Model's
// `beginRender`, as ⇧⌘R calls it) runs the window at most twice; 48
// `renderProgressed` ticks run it at most once per Model write. Both reach
// the hosted window's model through its debug `renderDrive` hook
// (HaloWindow+Render.swift); the ticks follow `startRender()` with no writer
// task, so only the test moves the progress. `bodies` gates the counts
// (CL-5); `timing` judges the step times, report-only, once the supervisor
// lists it in Tests/perf-suites.txt. Nested in BodyCountSuites, as every
// suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import HaloModel
import Testing

@testable import HaloApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloRenderTests {
        /// render: open Render… ≤ 2 window bodies (gate); p95 ≤ 33 ms report-only.
        static let openBodies = 2, openP95 = 33.0
        /// render: 48 progress ticks ≤ 48 window bodies (gate); p95 step ≤ 8.3 ms report-only.
        static let ticks = 48, tickBodies = 48, tickP95 = 8.3

        @Test(.timeLimit(.minutes(3))) func bodies() async throws {
            #if DEBUG
            let (open, ticked) = try await Self.measure()
            expectBodies(open, atMost: Self.openBodies, target: 1)
            expectBodies(ticked, atMost: Self.tickBodies, target: Self.ticks)
            #endif
        }

        @Test(.timeLimit(.minutes(6)), .disabled("report-only: waits on the supervisor listing it in Tests/perf-suites.txt"))
        func timing() async throws {
            #if DEBUG
            let (open, ticked) = try await Self.measure()
            expectP95(open, atMost: Self.openP95, target: Self.openP95)
            expectP95(ticked, atMost: Self.tickP95, target: Self.tickP95)
            #endif
        }

        #if DEBUG
        /// Opens Render… on the hosted `keyed` window, starts the render with no writer, then ticks its progress.
        static func measure() async throws -> (open: RenderStep, ticks: RenderStep) {
            HaloWindow.renderDrive = nil
            let project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            let w = RenderBudgetWindow(HaloWindow(model: project))
            defer { w.close() }
            try await w.settle()
            let drive = try #require(HaloWindow.renderDrive, "the window never installed its render hook")
            let open = try await w.measure("halo render, open Render…", bodies: HaloWindowPlaybackTests.windowBodies) {
                w.timed { drive { _ = $0.beginRender(HaloRenderSettings(format: .pngSequence)) } }
            }
            drive { _ = $0.startRender() }
            try await w.settle()
            let ticked = try await w.measure(
                "halo render, \(ticks) progress ticks", bodies: HaloWindowPlaybackTests.windowBodies
            ) {
                try await w.ticks(ticks) { i in drive { $0.renderProgressed(done: i) } }
            }
            drive { $0.cancelRender() }
            try await w.settle()
            return (open, ticked)
        }
        #endif
    }
}
#endif
