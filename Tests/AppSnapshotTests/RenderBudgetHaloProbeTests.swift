// RenderBudgetHaloProbeTests.swift: the frame probe's render budget
// (Tests/render-budgets.md; packet docs/blueprints/halo/features/core-loop.md,
// Quality tests) on the real window, through the harness
// (RenderBudgetHarness.swift). With `-SuitePerfProbe` on, recording a sample
// runs no window body: a 120-sample viewer drag stays at RenderBudgetHaloTests'
// bound of 3 window bodies and one second of playback at 24 + 6. `bodies`
// gates the counts; `timing` stays report-only until the supervisor lists it
// in Tests/perf-suites.txt. Nested in BodyCountSuites, as every suite that
// reads a body counter is. CL-3 adds the rows disabled; CL-9 turns `bodies`
// on against CL-8's recording. macOS only.
#if canImport(AppKit)
import Testing

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloProbeTests {
        /// render: probe on, 120-sample viewer drag ≤ 3 window bodies (gate).
        static let dragSamples = 120, dragBodies = 3
        /// render: probe on, 1 s of playback ≤ 24 frames + 6 (gate).
        static let playbackBodies = 24 + 6

        @Test(.timeLimit(.minutes(3)), .disabled("waits on CL-9")) func bodies() async throws {
            Issue.record("drag ≤ \(Self.dragBodies), playback ≤ \(Self.playbackBodies): not measured yet (CL-9)")
        }

        @Test(.timeLimit(.minutes(6)), .disabled("waits on CL-9")) func timing() async throws {
            Issue.record("probe-on step times: not measured yet (CL-9)")
        }
    }
}
#endif
