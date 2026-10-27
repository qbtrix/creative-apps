// RenderBudgetPhotoLiveTransformTests.swift: Free Transform's rotate drag on the real Photo window moves
// pixels the compositor already has (SuiteUI's CanvasHostView lift), so a drag sample does no pixel work.
// It hosts PhotoWindow on the `large` fixture (4000 x 3000, Noise on top, selected) with Free Transform begun,
// presses in the rotate zone off the box's bottom-right corner and turns the pointer 120 samples at 120 Hz
// round the box's centre. While the pointer is down Photo resamples the layer on the CPU 0 times
// (PhotoRenderCount.resamples, debug only) and the window's editor body runs at most once; the release draws
// the exact frame, one resample, and the draft has turned. Nested in BodyCountSuites: it reads process-wide
// counters. `RenderBudgetPhotoLiveTransformTimingTests` (a perf suite, Tests/perf-suites.txt) times the same
// drag on a 24 MP layer (6000 x 4000, one opaque layer): each sample's main-thread step, the event and the
// layout and display it forces, on a release build with testing and DEBUG on (Tests/render-budgets.md); its
// budget ratchets from what it measured toward the 4 ms target. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoLiveTransformTests {
        static let samples = 120

        @Test(.timeLimit(.minutes(2))) func rotateDragResamplesOnlyAtTheRelease() async throws {
            let draft = try RenderBudgetPhotoTransformTests.draft()
            let w = RenderBudgetWindow(PhotoWindow(model: draft.model).allowsWindowActivationEvents())
            defer { w.close() }
            let edited = try await RenderBudgetPhotoTransformTests.settle(w)
            try await Self.idle(w)  // the first picture is up before the press
            let drag = try await Self.rotateDrag(on: w)
            let before = Self.resamples()
            var during = 0
            let step = try await w.measure("photo live transform rotate drag, 120 samples", bodies: RenderBudgetPhotoTransformTests.bodies) {
                w.timed { w.send(.leftMouseDown, at: drag.start) }
                try await w.ticks(Self.samples) { w.send(.leftMouseDragged, at: drag.point($0)) }
                try await w.settle(200)  // any render a sample asked for lands
                during = Self.resamples() - before
                w.timed { w.send(.leftMouseUp, at: drag.point(Self.samples)) }
            }
            #expect(during == 0, "the drag resampled the layer on the CPU \(during) times before the release")
            let after = try #require(await RenderBudgetPhotoTransformTests.landed(edited) {
                ($0.transformSelection?.degrees).map { $0 != draft.before.degrees } ?? true
            })
            try await Self.idle(w)
            #expect(Self.resamples() - before == 1, "the release resampled \(Self.resamples() - before - during) times, not once")
            #expect(after.transformDraft != nil, "the rotate drag ended Free Transform")
            let degrees = try #require(after.transformSelection?.degrees)
            #expect(abs(degrees - draft.before.degrees) > 5, "the drag didn't turn the draft: \(degrees)°")
            expectBodies(step, atMost: 1, target: 1)
        }

        /// A press in the rotate zone off the draft's bottom-right corner and a pointer path that turns `degrees`
        /// round the box's centre over `samples` (window points, y up).
        struct RotateDrag {
            let start: CGPoint, centre: CGPoint
            var degrees = 30.0, samples = 120

            func point(_ i: Int) -> CGPoint {
                let (dx, dy) = (start.x - centre.x, start.y - centre.y)
                let a = -degrees * .pi / 180 * Double(i) / Double(samples)  // clockwise on screen, y up
                return CGPoint(x: centre.x + dx * cos(a) - dy * sin(a), y: centre.y + dx * sin(a) + dy * cos(a))
            }
        }

        static func rotateDrag<V: View>(on w: RenderBudgetWindow<V>) async throws -> RotateDrag {
            let corner = try #require(await w.element("suite.handles.bottomRight"), "no bottom-right handle on the draft")
            let box = try #require(await w.element("photo.canvas.transform-box"), "no transform box")
            // The rotate zone sits past the corner's hit square: 6 pt out, 16 pt across (HandleGeometry+Kernel).
            let start = CGPoint(x: corner.midX + 14, y: corner.midY - 14)
            return RotateDrag(start: start, centre: CGPoint(x: box.midX, y: box.midY))
        }

        /// Every resample of Free Transform's layer in the process so far (debug only).
        static func resamples() -> Int { PhotoRenderCount.resamples.withLock { $0 } }

        /// Waits up to 60 s for every canvas render in the process to finish.
        static func idle<V: View>(_ w: RenderBudgetWindow<V>) async throws {
            for _ in 0..<3000 where CanvasRenderer.inFlight != 0 { try await Task.sleep(for: .milliseconds(20)) }
            try await w.settle(100)
        }
    }
}

@MainActor @Suite struct RenderBudgetPhotoLiveTransformTimingTests {
    @Test(.timeLimit(.minutes(3))) func rotateDragStepOn24MegapixelsStaysInBudget() async throws {
        var model = PhotoWorkspace()
        try model.newImage(DocumentSetup(width: 6000, height: 4000))
        model.selectTool(.move)
        try model.beginTransform()
        let w = RenderBudgetWindow(PhotoWindow(model: model).allowsWindowActivationEvents())
        defer { w.close() }
        _ = try await BodyCountSuites.RenderBudgetPhotoTransformTests.settle(w)
        try await BodyCountSuites.RenderBudgetPhotoLiveTransformTests.idle(w)
        let drag = try await BodyCountSuites.RenderBudgetPhotoLiveTransformTests.rotateDrag(on: w)
        let step = try await w.measure("photo live transform rotate drag, 24 MP", bodies: { nil }) {
            try await w.drag(from: drag.start, samples: drag.samples, path: drag.point)
        }
        #expect(step.steps >= drag.samples, "\(step)")
        // Release, 2026-10-27, M2 Pro at load ~30: p95 16.8-17.9 ms, p50 8-9 ms, all of it SwiftUI updating the
        // handles and the Transform rows; no pixel work. Ratchet down as those move off SwiftUI.
        expectP95(step, atMost: 20, target: 4)
    }
}
#endif
