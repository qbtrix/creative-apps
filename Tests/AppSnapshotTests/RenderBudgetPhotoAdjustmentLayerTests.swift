// RenderBudgetPhotoAdjustmentLayerTests.swift (#2875, PJ-P2's adjustment-layer scrub): what an adjustment
// layer's Exposure scrub costs the real Photo window, on the render budget harness (RenderBudgetHarness.swift).
// It hosts PhotoWindow on the `large` fixture (4000 x 3000, three layers) with an Exposure adjustment layer
// added and selected, and sends 120 Exposure changes through the window's perform, as the inspector's bar
// slider does while it drags, then the gesture's end. Those samples run on the window's live copy
// (LiveTransformCopy+Kernel.swift), as a tone row's do, so the editor body runs at most 3 times, counted on a
// SuiteUI BodyTally in this window's environment (debug only). The test waits, up to 2 s, for the copy to
// land and reads Exposure and the undo step off the workspace. The step p95 (budget 16 ms) is printed, never
// asserted, until the supervisor lists this in Tests/perf-suites.txt. Nested in BodyCountSuites, as every
// suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoAdjustmentLayerTests {
        static let samples = 120

        @Test(.timeLimit(.minutes(2))) func exposureScrubOnAnAdjustmentLayerInThreeBodies() async throws {
            var model = try PhotoWorkspace.fixture(.large)
            model.addAdjustmentLayer(.exposure)
            let id = try #require(model.selectedLayerID)
            let tally = BodyTally()
            let w = RenderBudgetWindow(PhotoWindow(model: model).environment(\.bodyTally, tally))
            defer { w.close() }
            let bodies = { RenderBudgetPhotoToneTests.bodies(tally) }
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            try await w.settle(untilStable: bodies)
            let send = try #require(edited.send, "the window hands out no perform")
            let step = try await w.measure("photo adjustment layer exposure scrub, 120 steps", bodies: bodies) {
                try await w.ticks(Self.samples) { send(.adjustmentLayer(.adjust(id, .exposure(Self.exposure($0))))) }
                send(.adjustmentLayer(.endAdjust))
            }
            print("RENDER-BUDGET photo adjustment layer exposure scrub p95 \(String(format: "%.2f", step.p95)) ms (budget 16, print-only)")
            #expect(step.steps >= Self.samples, "\(step)")
            let last = Self.exposure(Self.samples)
            let after = try #require(await RenderBudgetPhotoTransformTests.landed(edited) { Self.exposure(of: id, in: $0) == last })
            #expect(Self.exposure(of: id, in: after) == last, "120 steps left Exposure at \(String(describing: Self.exposure(of: id, in: after)))")
            #expect(after.undoActionName == "Undo Exposure", "the last step is \(after.undoActionName)")
            expectBodies(step, atMost: 3, target: 3)
        }

        /// The scrub's value at step `i`: up to 2.4 EV, then round again from 0.02 for a longer run.
        static func exposure(_ i: Int) -> Float { Float((i - 1) % 120 + 1) * 0.02 }

        /// The adjustment layer's Exposure in `workspace`; nil when it isn't an adjustment layer there.
        static func exposure(of id: PhotoLayer.ID, in workspace: PhotoWorkspace) -> Float? {
            guard let layer = workspace.layers.first(where: { $0.id == id }), case .adjustment(let settings) = layer.kind
            else { return nil }
            return settings.exposure
        }
    }
}
#endif
