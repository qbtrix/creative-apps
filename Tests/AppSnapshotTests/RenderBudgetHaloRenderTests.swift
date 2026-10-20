// RenderBudgetHaloRenderTests.swift: the render sheet's render budget
// (Tests/render-budgets.md; packet docs/blueprints/halo/features/core-loop.md,
// Quality tests) on the real window, through the harness
// (RenderBudgetHarness.swift). Opening File > Render… (⇧⌘R) runs the window
// at most twice; 48 `renderProgressed` ticks run it at most once per Model
// write. `bodies` gates the counts; `timing` judges the step times,
// report-only, once the supervisor lists it in Tests/perf-suites.txt. Nested
// in BodyCountSuites, as every suite that reads a body counter is. CL-3 adds
// the rows disabled; CL-5 turns `bodies` on against CL-4's sheet. macOS only.
#if canImport(AppKit)
import Testing

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloRenderTests {
        /// render: open Render… ≤ 2 window bodies (gate); p95 ≤ 33 ms report-only.
        static let openBodies = 2, openP95 = 33.0
        /// render: 48 progress ticks ≤ 48 window bodies (gate); p95 step ≤ 8.3 ms report-only.
        static let ticks = 48, tickBodies = 48, tickP95 = 8.3

        @Test(.timeLimit(.minutes(3)), .disabled("waits on CL-5")) func bodies() async throws {
            Issue.record("open ≤ \(Self.openBodies), \(Self.ticks) ticks ≤ \(Self.tickBodies): not measured yet (CL-5)")
        }

        @Test(.timeLimit(.minutes(6)), .disabled("waits on CL-5")) func timing() async throws {
            Issue.record("open p95 ≤ \(Self.openP95) ms, tick p95 ≤ \(Self.tickP95) ms: not measured yet (CL-5)")
        }
    }
}
#endif
