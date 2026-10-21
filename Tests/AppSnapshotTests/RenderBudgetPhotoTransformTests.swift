// RenderBudgetPhotoTransformTests.swift (transform PT-7, quality rows "render:
// 120-sample corner drag on a 12 MP layer" and "render: 120-sample rotation
// scrub"): what Free Transform's draft costs the real Photo window, on the
// render budget harness (RenderBudgetHarness.swift). It hosts PhotoWindow on
// the `large` fixture (4000 x 3000, 12 MP, Noise selected) with the Move tool
// and Free Transform begun, so the canvas shows SuiteUI's handles on Noise's
// box and the inspector the transform rows. `cornerDragInThreeBodies` drags the
// bottom-right handle out by 120 samples at 120 Hz; `rotationScrubInThreeBodies`
// steps the Rotation row 120 times, as VoiceOver adjusts it. The draft is a
// preview, so the window's editor body (a debug-only counter) runs at most 3
// times either way. The window needs `allowsWindowActivationEvents`: a test
// process only sends activation clicks, and the handles are a SwiftUI gesture.
// Each test checks the draft moved: the drag grew its box, the scrub turned it
// (`setTransform`, PT-5). The step p95 (budget 16 ms) is printed, never asserted, until the
// supervisor lists these in Tests/perf-suites.txt. Nested in BodyCountSuites,
// as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoTransformTests {
        static let samples = 120

        @Test(.timeLimit(.minutes(2))) func cornerDragInThreeBodies() async throws {
            let draft = try Self.draft()
            let w = RenderBudgetWindow(PhotoWindow(model: draft.model).allowsWindowActivationEvents())
            defer { w.close() }
            let edited = try await Self.settle(w)
            let corner = try #require(await w.element("suite.handles.bottomRight"), "no bottom-right handle on the draft")
            let start = CGPoint(x: corner.midX, y: corner.midY)
            let step = try await w.measure("photo transform corner drag, 120 samples", bodies: Self.bodies) {
                // Window points have y up: out from the bottom-right corner is right and down.
                try await w.drag(from: start, by: CGVector(dx: 120, dy: -80), samples: Self.samples)
            }
            print("RENDER-BUDGET photo transform corner drag p95 \(String(format: "%.2f", step.p95)) ms (budget 16, print-only)")
            #expect(step.steps >= Self.samples, "\(step)")
            let after = try #require(edited.workspace)
            #expect(after.transformDraft != nil, "the corner drag ended Free Transform")
            let box = try #require(after.transformSelection?.box)
            #expect(box.width > draft.before.box.width && box.height > draft.before.box.height,
                    "the corner drag didn't grow the draft: \(draft.before.box) to \(box)")
            expectBodies(step, atMost: 3, target: 3)
        }

        @Test(.timeLimit(.minutes(2))) func rotationScrubInThreeBodies() async throws {
            let draft = try Self.draft()
            let w = RenderBudgetWindow(PhotoWindow(model: draft.model).allowsWindowActivationEvents())
            defer { w.close() }
            let edited = try await Self.settle(w)
            _ = try #require(await w.element("suite.transform.rotation"), "no Rotation row in the inspector")
            var found = false
            let step = try await w.measure("photo transform rotation scrub, 120 steps", bodies: Self.bodies) {
                found = try await w.adjust("suite.transform.rotation", steps: Self.samples)
            }
            print("RENDER-BUDGET photo transform rotation scrub p95 \(String(format: "%.2f", step.p95)) ms (budget 16, print-only)")
            #expect(found, "the Rotation row isn't adjustable")
            #expect(step.steps >= Self.samples, "\(step)")
            let after = try #require(edited.workspace)
            #expect(after.transformDraft != nil, "the scrub ended Free Transform")
            let degrees = try #require(after.transformSelection?.degrees)
            #expect(degrees != draft.before.degrees, "the scrub didn't turn the draft from \(draft.before.degrees)°")
            expectBodies(step, atMost: 3, target: 3)
        }

        struct Draft {
            let model: PhotoWorkspace
            /// The draft's box as it began.
            let before: TransformBox
        }

        /// The window's editor body runs (debug only).
        static func bodies() -> Int? { BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }

        /// The large fixture with the Move tool and Free Transform begun on Noise.
        static func draft() throws -> Draft {
            var model = try PhotoWorkspace.fixture(.large)
            model.selectTool(.move)
            try model.beginTransform()
            let before = try #require(model.transformSelection)
            return Draft(model: model, before: before)
        }

        /// Waits for the hosted window to settle; returns its edited view, the draft still up.
        static func settle<V: View>(_ w: RenderBudgetWindow<V>) async throws -> PhotoWindowEditedView {
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            try await w.settle(untilStable: bodies)
            #expect(edited.workspace?.transformDraft != nil, "the window opened without the draft")
            return edited
        }
    }
}
#endif
