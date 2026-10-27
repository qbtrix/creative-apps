// RenderBudgetPhotoToneTests.swift (tone-controls PT-5, the quality row "render: 120-step Temperature drag"):
// what the tone rows cost the real Photo window, on the render budget harness (RenderBudgetHarness.swift).
// It hosts PhotoWindow on the sample picture with the Adjust panel up and steps the Temperature row
// (`suite.tone.temperature`) 120 times, as VoiceOver adjusts it. Each step is one `tone.set` under the
// row's drag token, and those samples run on the window's live copy (LiveTransformCopy+Kernel.swift),
// so the window's editor body (a debug-only counter) runs at most 3 times. The window takes the copy
// back once the steps go quiet, so the test reads the workspace after waiting, up to 2 s, for
// Temperature to reach the top of its range (each VoiceOver step is its own gesture and undo step,
// and reads the row's value off the live copy). The step p95 (budget 16 ms) is
// printed, never asserted, until the supervisor lists this in Tests/perf-suites.txt. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SuiteImaging
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoToneTests {
        static let samples = 120

        @Test(.timeLimit(.minutes(2))) func temperatureDragInThreeBodies() async throws {
            let model = try PhotoWorkspace.fixture(.sample)
            let before = model.adjustments.tone.value(.temperature)
            let w = RenderBudgetWindow(PhotoWindow(model: model))
            defer { w.close() }
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            try await w.settle(untilStable: Self.bodies)
            _ = try #require(await w.element("suite.tone.temperature"), "no Temperature row in the Adjust panel")
            var found = false
            let step = try await w.measure("photo tone temperature drag, 120 steps", bodies: Self.bodies) {
                found = try await w.adjust("suite.tone.temperature", steps: Self.samples)
            }
            print("RENDER-BUDGET photo tone temperature drag p95 \(String(format: "%.2f", step.p95)) ms (budget 16, print-only)")
            #expect(found, "the Temperature row isn't adjustable")
            #expect(step.steps >= Self.samples, "\(step)")
            let after = try #require(await RenderBudgetPhotoTransformTests.landed(edited) {
                $0.adjustments.tone.value(.temperature) == ToneSlider.temperature.range.upperBound
            })
            // Each step reads the row's value off the live copy; rows that read the workspace would send 1 each time.
            #expect(after.adjustments.tone.value(.temperature) == ToneSlider.temperature.range.upperBound,
                    "120 steps from \(before) took Temperature to \(after.adjustments.tone.value(.temperature)), not the top")
            #expect(after.undoActionName == "Undo Temperature", "the last step is \(after.undoActionName)")
            expectBodies(step, atMost: 3, target: 3)
        }

        /// The window's editor body runs (debug only).
        static func bodies() -> Int? { BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
    }
}
#endif
