// RenderBudgetPhotoAdjustmentLayerScrubTests.swift: the adjustment-layer Exposure scrub (#2875, journey
// PhotoJourneyTests/testAdjustmentLayerScrubLatency) on the real Photo window at real size, hosted on the render
// budget harness (RenderBudgetHarness.swift). The `large` fixture (4000 x 3000, three layers) gets an Exposure
// adjustment layer, then 90 slider samples go through the window's intent hook as the inspector row sends them
// (`.adjustmentLayer(.adjust)`, one `.endAdjust` on release). Each sample runs PhotoEditor's body (the window
// body, a debug-only counter) at most 3 times in all, as a tone-row drag does, and the release leaves one
// "Exposure" undo step with the last value. The p95 (≤ 8 ms, 16 ms hard) is printed, not gated: a step-time
// budget belongs in a Tests/perf-suites.txt test, which only the supervisor lists. Nested in BodyCountSuites: it
// reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoAdjustmentLayerScrubTests {
        static let samples = 90

        @Test(.timeLimit(.minutes(3))) func exposureScrubOnALargeDocument() async throws {
            var model = try PhotoWorkspace.fixture(.large)
            model.addAdjustmentLayer(.exposure)
            let id = try #require(model.selectedLayerID)
            let w = RenderBudgetWindow(PhotoWindow(model: model), size: CGSize(width: 1800, height: 820))
            defer { w.close() }
            let bodies = { BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(untilStable: bodies)
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let send = try #require(edited.send)

            let step = try await w.measure("photo adjustment-layer Exposure scrub, 4000x3000, \(Self.samples) samples", bodies: bodies) {
                try await w.ticks(Self.samples) { i in send(.adjustmentLayer(.adjust(id, .exposure(Float(i) * 0.02)))) }
            }
            send(.adjustmentLayer(.endAdjust))
            try await w.settle(untilStable: bodies)
            let after = try #require(edited.workspace)
            let index = try #require(after.layers.firstIndex { $0.id == id })
            guard case .adjustment(let settings) = after.layers[index].kind else {
                Issue.record("layer \(id) is no longer an adjustment layer")
                return
            }
            #expect(abs(settings.exposure - Float(Self.samples) * 0.02) < 0.0001)
            #expect(after.undoActionName == "Undo Exposure")
            expectBodies(step, atMost: 3, target: 1)
            print("RENDER-BUDGET photo adjustment-layer scrub p95 \(String(format: "%.2f", step.p95)) ms (budget 16, target 8)")
        }
    }
}
#endif
