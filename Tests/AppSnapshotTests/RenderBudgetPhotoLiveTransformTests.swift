// RenderBudgetPhotoLiveTransformTests.swift: Free Transform's rotate drag on the real Photo window moves
// pixels the compositor already has (SuiteUI's CanvasHostView lift), so a drag sample does no pixel work.
// It hosts PhotoWindow on a 400 x 300 one-layer image with Free Transform begun,
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
// (Tests/render-budgets.md). `PixelMover` runs both measurements over every drag that moves a layer's
// existing pixels (each PhotoTool but the paint, area, crop, pick, type and path tools, plus Free Transform's
// body drag), so a Select drag pressed on a layer (the Move it folds in) meets the same budget and a new pixel-moving tool fails until it uses the
// lift. macOS only.
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
            let (before, bodiesBefore) = (Self.resamples(), BodyCountSuites.RenderBudgetPhotoTransformTests.bodies() ?? 0)
            var (during, lifted, bodiesDuring) = (0, false, 0)
            let step = try await w.measure("photo live transform rotate drag, \(choice), 120 samples", bodies: BodyCountSuites.RenderBudgetPhotoTransformTests.bodies) {
                w.timed { w.send(.leftMouseDown, at: drag.start) }
                try await w.ticks(Self.samples) { w.send(.leftMouseDragged, at: drag.point($0)) }
                try await w.settle(200)  // any render a sample asked for lands
                during = Self.resamples() - before
                lifted = try await Self.lifted(w)
                bodiesDuring = (BodyCountSuites.RenderBudgetPhotoTransformTests.bodies() ?? 0) - bodiesBefore
                w.timed { w.send(.leftMouseUp, at: drag.point(Self.samples)) }
            }
            #expect(during == 0, "\(choice): the drag resampled the layer on the CPU \(during) times before the release")
            #expect(lifted, "\(choice): the drag never lifted the layer onto the live layer")
            let after = try #require(await BodyCountSuites.RenderBudgetPhotoTransformTests.landed(edited) {
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
            let (before, bodiesBefore) = (Self.resamples(), BodyCountSuites.RenderBudgetPhotoTransformTests.bodies() ?? 0)
            var (during, lifted, bodiesDuring) = (0, false, 0)
            let step = try await w.measure("photo live transform canvas body drag, 120 samples", bodies: BodyCountSuites.RenderBudgetPhotoTransformTests.bodies) {
                try await w.ticks(Self.samples) { i in
                    send(.drag(CGPoint(x: 200 + Double(i - 1) * 2, y: 150), CGPoint(x: 200 + Double(i) * 2, y: 150 + Double(i) / 2)))
                }
                try await w.settle(200)
                during = Self.resamples() - before
                lifted = try await Self.lifted(w)
                bodiesDuring = (BodyCountSuites.RenderBudgetPhotoTransformTests.bodies() ?? 0) - bodiesBefore
                w.timed { send(.endDrag) }
            }
            #expect(during == 0, "the canvas drag resampled the layer on the CPU \(during) times before the release")
            #expect(lifted, "the canvas drag never lifted the layer")
            let after = try #require(await BodyCountSuites.RenderBudgetPhotoTransformTests.landed(edited) {
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

        /// A 400 x 300 white image (one pixel layer) with the Move tool and Free Transform begun: small, so a debug
        /// build's lift and the release's exact frame (a lanczos3 resample on the CPU) stay quick on a CI runner.
        static func draft() throws -> RenderBudgetPhotoTransformTests.Draft {
            var model = PhotoWorkspace()
            try model.newImage(DocumentSetup(width: 400, height: 300))
            model.selectTool(.select)
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

        /// Waits up to `limit` of wall clock for the window's canvas renders and its live-layer pixels to finish;
        /// past that it prints what is still busy and goes on, so a slow runner shows the cause, not a time limit.
        /// False when it gave up: a test that counts work from here on `#require`s true.
        @discardableResult
        static func idle<V: View>(_ w: RenderBudgetWindow<V>, limit: Duration = .seconds(60)) async throws -> Bool {
            // This window's renderer only: windows of suites running alongside keep the process-wide count busy.
            let renderer = canvas(in: w.host).flatMap(CanvasRenderer.rendering(into:))
            let deadline = ContinuousClock.now + limit
            var settled = true
            while renderer?.isSettled == false || (renderer == nil && CanvasRenderer.inFlight != 0) {
                guard ContinuousClock.now < deadline else {
                    let busy = renderer == nil ? "\(CanvasRenderer.inFlight) renders in the process"
                        : renderer?.isIdle == false ? "a canvas render" : "the live layer's pixels (a lift sprite)"
                    print("RENDER-BUDGET idle: still busy after \(limit): \(busy)")
                    settled = false
                    break
                }
                try await Task.sleep(for: .milliseconds(20))
            }
            try await w.settle(100)
            return settled
        }

        struct NoRenderer: Error {}
    }
}

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoLiveTransformTimingTests {
        @Test(.timeLimit(.minutes(3))) func rotateDragStepIsUnder4MillisecondsOn24Megapixels() async throws {
            var model = PhotoWorkspace()
            try model.newImage(DocumentSetup(width: 6000, height: 4000))
            model.selectTool(.select)
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

        /// Every pixel mover's straight drag on 24 MP: the same step bound as the rotate drag.
        @Test(.timeLimit(.minutes(3)), arguments: PixelMover.allCases)
        func pixelMoverStepIsUnder4MillisecondsOn24Megapixels(_ mover: PixelMover) async throws {
            let model = try mover.model(width: 6000, height: 4000)
            let w = RenderBudgetWindow(PhotoWindow(model: model).allowsWindowActivationEvents())
            defer { w.close() }
            _ = try await PixelMover.settle(w)
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
            let start = try #require(PixelMover.centre(of: w), "no canvas")
            let step = try await w.measure("photo \(mover) drag, 24 MP", bodies: { nil }) {
                try await w.drag(from: start, by: PixelMover.offset)
            }
            #expect(step.steps >= 120, "\(step)")
            expectP95(step, atMost: 4, target: 4)
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
        }
    }
}

/// A canvas drag that moves a layer's existing pixels across the canvas: a tool's, or Free Transform's body
/// drag. Every such drag rides the compositor's live layer (PhotoTransformLift+Kernel.swift): no resample and no
/// editor body until the release. The list is every PhotoTool but `staysPut`, so a new tool that moves pixels
/// is measured by default until it uses the lift.
enum PixelMover: CustomStringConvertible, Sendable {
    case tool(PhotoTool)
    case freeTransform

    /// The tools whose drag leaves the layer's pixels where they are: paint and retouch lay new pixels (brush,
    /// eraser, clone, heal, spot heal, remove, bucket, gradient), the area tools and crop draw a selection or
    /// a crop box, and the rest pick a colour (eyedropper), type (text) or draw paths (pen).
    static let staysPut: Set<PhotoTool> = [
        .brush, .eraser, .clone, .heal, .spotHeal, .remove, .bucket, .gradient,
        .marquee, .ellipse, .lasso, .polygon, .wand, .crop, .eyedropper, .text, .pen,
    ]

    static var allCases: [PixelMover] {
        PhotoTool.allCases.filter { !staysPut.contains($0) }.map(PixelMover.tool) + [.freeTransform]
    }

    /// The drag: 120 window points to the right over 120 samples, from the canvas's centre.
    static let offset = CGVector(dx: 120, dy: 0)

    var description: String {
        switch self {
        case .tool(let tool): "\(tool.rawValue) tool"
        case .freeTransform: "free transform body"
        }
    }

    /// CPU resamples the release lays: Free Transform's exact frame is one; a tool's move is an offset change.
    var releaseResamples: Int { self == .freeTransform ? 1 : 0 }

    /// A white one-layer image of `width` x `height` with the mover ready to drag.
    func model(width: Int, height: Int) throws -> PhotoWorkspace {
        var model = PhotoWorkspace()
        try model.newImage(DocumentSetup(width: Double(width), height: Double(height)))
        switch self {
        case .tool(let tool): model.selectTool(tool)
        case .freeTransform:
            model.selectTool(.select)
            try model.beginTransform()
        }
        return model
    }

    /// Whether the drag moved the layer in `after`, from `before`.
    func moved(_ before: PhotoWorkspace, _ after: PhotoWorkspace) -> Bool {
        switch self {
        case .tool: after.selectedLayer?.offsetX != before.selectedLayer?.offsetX
        case .freeTransform: after.transformSelection?.box.minX != before.transformSelection?.box.minX
        }
    }

    /// The undo step the release records; nil when the release records none (Free Transform's draft is still up).
    var undoName: String? { self == .freeTransform ? nil : "Undo Move Layer" }

    /// The canvas's centre in window points; nil before the canvas is up.
    @MainActor static func centre<V: View>(of w: RenderBudgetWindow<V>) -> CGPoint? {
        guard let canvas = BodyCountSuites.RenderBudgetPhotoLiveTransformTests.canvas(in: w.host) else { return nil }
        let frame = canvas.convert(canvas.bounds, to: nil)
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    /// Waits for the hosted window to settle; returns its edited view.
    @MainActor static func settle<V: View>(_ w: RenderBudgetWindow<V>) async throws -> PhotoWindowEditedView {
        let edited = try #require(await w.first(PhotoWindowEditedView.self))
        try await w.settle(untilStable: BodyCountSuites.RenderBudgetPhotoTransformTests.bodies)
        return edited
    }
}

extension PixelMover: Equatable {}

extension BodyCountSuites.RenderBudgetPhotoLiveTransformTests {
    /// Every pixel mover's straight drag across the canvas body: the layer rides the live layer with no CPU
    /// resample and at most one editor body until the release, which lays its one step.
    @Test(.timeLimit(.minutes(2)), arguments: PixelMover.allCases)
    func pixelMoverDragResamplesOnlyAtTheRelease(_ mover: PixelMover) async throws {
        let model = try mover.model(width: 400, height: 300)
        let w = RenderBudgetWindow(PhotoWindow(model: model).allowsWindowActivationEvents())
        defer { w.close() }
        let edited = try await PixelMover.settle(w)
        try await Self.idle(w)
        let start = try #require(PixelMover.centre(of: w), "no canvas")
        let (before, bodiesBefore) = (Self.resamples(), BodyCountSuites.RenderBudgetPhotoTransformTests.bodies() ?? 0)
        var (during, lifted, bodiesDuring) = (0, false, 0)
        let step = try await w.measure("photo \(mover) drag, 120 samples", bodies: BodyCountSuites.RenderBudgetPhotoTransformTests.bodies) {
            try await w.drag(from: start, samples: Self.samples, release: false) {
                CGPoint(x: start.x + PixelMover.offset.dx * Double($0) / Double(Self.samples), y: start.y)
            }
            try await w.settle(200)
            during = Self.resamples() - before
            lifted = try await Self.lifted(w)
            bodiesDuring = (BodyCountSuites.RenderBudgetPhotoTransformTests.bodies() ?? 0) - bodiesBefore
            w.timed { w.send(.leftMouseUp, at: CGPoint(x: start.x + PixelMover.offset.dx, y: start.y)) }
        }
        #expect(during == 0, "\(mover): the drag resampled the layer on the CPU \(during) times before the release")
        #expect(lifted, "\(mover): the drag never lifted the layer onto the live layer")
        let after = try #require(await BodyCountSuites.RenderBudgetPhotoTransformTests.landed(edited) { mover.moved(model, $0) })
        try await Self.idle(w)
        #expect(Self.resamples() - before == mover.releaseResamples,
                "\(mover): the release resampled \(Self.resamples() - before - during) times, not \(mover.releaseResamples)")
        #expect(Self.canvas(in: w.host)?.hasLiveLayer == false, "\(mover): the live layer stayed up")
        #expect(mover.moved(model, after), "\(mover): the drag didn't move the layer")
        if let name = mover.undoName { #expect(after.undoActionName == name, "\(mover): the release recorded \(after.undoActionName)") }
        #if DEBUG
        #expect(bodiesDuring <= 1, "\(mover): the window's editor body ran \(bodiesDuring) times with the pointer down")
        #endif
        expectBodies(step, atMost: 3, target: 1)
    }
}
#endif
