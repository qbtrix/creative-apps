// RenderBudgetPhotoTests.swift: Photo's render budget (Tests/render-budgets.md).
// The brush stroke already has its body bound in the gate
// (PhotoWindowStrokeTests: PhotoEditor's body runs at most once over a
// 120-sample stroke); this suite's `timing` (Tests/perf-suites.txt,
// report-only) runs the same stroke and judges its step times, and holds
// text-layers' 8K keystroke and Size scrub p95s for the same reason. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import Testing

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoTests {
        @Test(.timeLimit(.minutes(2))) func timing() async throws {
            let stroke = try await BodyCountSuites.PhotoWindowStrokeTests.stroke()
            // Target: a stroke sample fits one 120 Hz frame.
            expectP95(stroke.step, atMost: 11, target: 8.3)  // dev: 7.1 ms
        }

        /// text-layers' keystroke budget (RenderBudgetPhotoTextTests): a key into a box on 8K, p95 within one frame.
        @Test(.timeLimit(.minutes(2))) func typeOnEightKInSixteenMs() async throws {
            let text = BodyCountSuites.RenderBudgetPhotoTextTests.self
            expectP95(try await text.typeTwentyOnEightK("photo type 20 chars on 8K, timed"), atMost: 16, target: 8)
        }

        /// text-layers' Size scrub on a text layer of an 8K image, p95 within one frame.
        @Test(.timeLimit(.minutes(2))) func textSizeScrubInSixteenMs() async throws {
            let text = BodyCountSuites.RenderBudgetPhotoTextTests.self
            expectP95(try await text.scrubSize("photo text Size scrub, 120 samples on 8K, timed"), atMost: 16, target: 8)
        }
    }
}
#endif
