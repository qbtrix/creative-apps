// RenderBudgetPhotoTests.swift: Photo's render budget (Tests/render-budgets.md).
// The brush stroke already has its body bound in the gate
// (PhotoWindowStrokeTests: PhotoEditor's body runs at most once over a
// 120-sample stroke); this suite's `timing` (Tests/perf-suites.txt,
// report-only) runs the same stroke and judges its step times. macOS only.
#if canImport(AppKit)
import Testing

@MainActor @Suite struct RenderBudgetPhotoTests {
    @Test(.timeLimit(.minutes(2))) func timing() async throws {
        let stroke = try await BodyCountSuites.PhotoWindowStrokeTests.stroke()
        // Target: a stroke sample fits one 120 Hz frame.
        expectP95(stroke.step, atMost: 11, target: 8.3)  // dev: 7.1 ms
    }
}
#endif
