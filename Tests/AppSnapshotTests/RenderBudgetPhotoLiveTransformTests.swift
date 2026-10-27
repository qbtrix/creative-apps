// RenderBudgetPhotoLiveTransformTests.swift: Free Transform's rotate drag on the real Photo window moves
// pixels the compositor already has (SuiteUI's CanvasHostView lift), so a drag sample does no pixel work.
// It hosts PhotoWindow on the `sample` fixture (800 x 600, one pixel layer) with Free Transform begun,
// presses in the rotate zone off the box's bottom-right corner and turns the pointer 120 samples at 120 Hz
// round the box's centre, on the tile path and on Metal; a canvas drag on the box's body (the window's drag
// intents) does the same through the live copy. While the pointer is down Photo resamples the layer on the CPU
// 0 times (PhotoRenderCount.resamples, debug only), the layer rides the canvas's live layer and the window's
// editor body runs at most once with the pointer down; the release draws the exact frame, one resample, drops the live layer, and
// the draft has turned or moved. Nested in BodyCountSuites: it reads process-wide
// counters. `RenderBudgetPhotoLiveTransformTimingTests` (a perf suite, Tests/perf-suites.txt, nested in
// BodyCountSuites too so no other window's renders count) times the same
// drag on a 24 MP layer (6000 x 4000, one opaque layer): each sample's main-thread step, the event and the
// layout and display it forces, has a p95 of at most 4 ms on a release build with testing and DEBUG on
// (Tests/render-budgets.md). macOS only.
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

        /// The handles' rotate drag, on the tile path and on Metal (resident tiles, the app's default).
        @Test(.timeLimit(.minutes(3)), arguments: [RenderingChoice.cpu, .gpu])
        func rotateDragResamplesOnlyAtTheRelease(_ choice: RenderingChoice) async throws {
            let draft = try Self.draft()
            let w = RenderBudgetWindow(AnyView(PhotoWindow(model: draft.model).allowsWindowActivationEvents()
                .environment(\.photoRendering, Self.rendering(choice))))
            defer { w.close() }
            let edited = try await RenderBudgetPhotoTransformTests.settle(w)
            try await Self.idle(w)  // the first picture is up before the press
            let drag = try await Self.rotateDrag(on: w)
            let (before, bodiesBefore) = (Self.resamples(), RenderBudgetPhotoTransformTests.bodies() ?? 0)
            var (during, lifted, bodiesDuring) = (0, false, 0)
            let step = try await w.measure("photo live transform rotate drag, \(choice), 120 samples", bodies: RenderBudgetPhotoTransformTests.bodies) {
                w.timed { w.send(.leftMouseDown, at: drag.start) }
                try await w.ticks(Self.samples) { w.send(.leftMouseDragged, at: drag.point($0)) }
                try await w.settle(200)  // any render a sample asked for lands
                during = Self.resamples() - before
                lifted = try await Self.lifted(w)
                bodiesDuring = (RenderBudgetPhotoTransformTests.bodies() ?? 0) - bodiesBefore
                w.timed { w.send(.leftMouseUp, at: drag.point(Self.samples)) }
            }
            #expect(during == 0, "\(choice): the drag resampled the layer on the CPU \(during) times before the release")
            #expect(lifted, "\(choice): the drag never lifted the layer onto the live layer")
            let after = try #require(await RenderBudgetPhotoTransformTests.landed(edited) {
                ($0.transformSelection?.degrees).map { $0 != draft.before.degrees } ?? true
            })
            try await Self.idle(w)
            #expect(Self.resamples() - before == 1, "\(choice): the release resampled \(Self.resamples() - before - during) times, not once")
            #expect(Self.canvas(in: w.host)?.hasLiveLayer == false, "\(choice): the live layer stayed up")
            #expect(after.transformDraft != nil, "the rotate drag ended Free Transform")
            let degrees = try #require(after.transformSelection?.degrees)
            #expect(abs(degrees - draft.before.degrees) > 5, "the drag didn't turn the draft: \(degrees)°")
            #if DEBUG
            #expect(bodiesDuring <= 1, "the window's editor body ran \(bodiesDuring) times with the pointer down")
            #endif
            // The release adopts the copy (one body) and its exact picture's time reaches the status line.
            expectBodies(step, atMost: 3, target: 1)
        }

        /// A canvas drag on the draft's body (CanvasViewport's drag, the route the captain's rotate took), sent as
        /// the window's drag intents: it moves the draft on the live copy with no CPU resample until the release.
        @Test(.timeLimit(.minutes(2))) func canvasBodyDragResamplesOnlyAtTheRelease() async throws {
            let draft = try Self.draft()
            let w = RenderBudgetWindow(PhotoWindow(model: draft.model).allowsWindowActivationEvents())
            defer { w.close() }
            let edited = try await RenderBudgetPhotoTransformTests.settle(w)
            try await Self.idle(w)
            let send = try #require(edited.send)
            let (before, bodiesBefore) = (Self.resamples(), RenderBudgetPhotoTransformTests.bodies() ?? 0)
            var (during, lifted, bodiesDuring) = (0, false, 0)
            let step = try await w.measure("photo live transform canvas body drag, 120 samples", bodies: RenderBudgetPhotoTransformTests.bodies) {
                try await w.ticks(Self.samples) { i in
                    send(.drag(CGPoint(x: 300 + Double(i - 1) * 2, y: 300), CGPoint(x: 300 + Double(i) * 2, y: 300 + Double(i) / 2)))
                }
                try await w.settle(200)
                during = Self.resamples() - before
                lifted = try await Self.lifted(w)
                bodiesDuring = (RenderBudgetPhotoTransformTests.bodies() ?? 0) - bodiesBefore
                w.timed { send(.endDrag) }
            }
            #expect(during == 0, "the canvas drag resampled the layer on the CPU \(during) times before the release")
            #expect(lifted, "the canvas drag never lifted the layer")
            let after = try #require(await RenderBudgetPhotoTransformTests.landed(edited) {
                ($0.transformSelection?.box).map { $0 != draft.before.box } ?? true
            })
            try await Self.idle(w)
            #expect(Self.resamples() - before == 1, "the release resampled \(Self.resamples() - before - during) times, not once")
            let box = try #require(after.transformSelection?.box)
            #expect(box.minX > draft.before.box.minX + 100, "the canvas drag didn't move the draft: \(box)")
            #if DEBUG
            #expect(bodiesDuring <= 1, "the window's editor body ran \(bodiesDuring) times with the pointer down")
            #endif
            // The release adopts the copy (one body) and its exact picture's time reaches the status line.
            expectBodies(step, atMost: 3, target: 1)
        }

        /// Whether the window's canvas shows a live layer, waiting up to 10 s for the lift's one render (the picture
        /// under it) to land; prints how long the pointer waited.
        static func lifted<V: View>(_ w: RenderBudgetWindow<V>) async throws -> Bool {
            let clock = ContinuousClock(), began = clock.now
            for _ in 0..<500 {
                if w.host.subviews.isEmpty == false, Self.canvas(in: w.host)?.hasLiveLayer == true {
                    print("RENDER-BUDGET photo live transform: lifted \(clock.now - began) after the drag's samples")
                    return true
                }
                try await Task.sleep(for: .milliseconds(20))
            }
            return false
        }

        /// The window's canvas host view.
        static func canvas(in view: NSView) -> CanvasHostView? {
            if let host = view as? CanvasHostView { return host }
            for child in view.subviews { if let found = canvas(in: child) { return found } }
            return nil
        }

        /// The sample fixture (800 x 600, one pixel layer) with the Move tool and Free Transform begun: small, so a
        /// debug build's one lift (the layer's bytes and the picture under it) lands within the drag.
        static func draft() throws -> RenderBudgetPhotoTransformTests.Draft {
            var model = try PhotoWorkspace.fixture(.sample)
            model.selectTool(.move)
            try model.beginTransform()
            return RenderBudgetPhotoTransformTests.Draft(model: model, before: try #require(model.transformSelection))
        }

        /// A rendering preference fixed on `choice`.
        static func rendering(_ choice: RenderingChoice) -> PhotoRendering {
            PhotoRendering(preference: FakeRenderingPreference(choice: choice))
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

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoLiveTransformTimingTests {
        @Test(.timeLimit(.minutes(3))) func rotateDragStepIsUnder4MillisecondsOn24Megapixels() async throws {
            var model = PhotoWorkspace()
            try model.newImage(DocumentSetup(width: 6000, height: 4000))
            model.selectTool(.move)
            try model.beginTransform()
            let w = RenderBudgetWindow(PhotoWindow(model: model).allowsWindowActivationEvents())
            defer { w.close() }
            _ = try await RenderBudgetPhotoTransformTests.settle(w)
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
            let drag = try await RenderBudgetPhotoLiveTransformTests.rotateDrag(on: w)
            let step = try await w.measure("photo live transform rotate drag, 24 MP", bodies: { nil }) {
                try await w.drag(from: drag.start, samples: drag.samples, path: drag.point)
            }
            #expect(step.steps >= drag.samples, "\(step)")
            // Release, 2026-10-27, M2 Pro: p95 2.1 ms, p50 1.2 ms; the layer lifts about 0.15 s after the press.
            expectP95(step, atMost: 4, target: 4)
            // The renderer outlives its window: the release's exact picture finishes before the next suite counts.
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
        }
    }
}
#endif
