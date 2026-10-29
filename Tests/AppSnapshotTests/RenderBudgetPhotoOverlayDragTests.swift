// RenderBudgetPhotoOverlayDragTests.swift: a drag whose only picture is an overlay mark (the marquee's ants, the
// lasso's path, the crop box) does no pixel work on the real Photo window (#6020). `OverlayDragger` lists every
// PhotoTool whose drag draws a selection or a crop box, derived from the enum minus an explicit exclusion list, so
// a new area tool is measured by default. Each hosts PhotoWindow on a 24 MP one-layer image (6000 x 4000), presses
// at the canvas's centre and drags 120 samples at 120 Hz along three legs (right, down, back), a path that encloses
// an area for the lasso and ends away from the press for the others. While the pointer is down the canvas
// composites 0 regions (PhotoRenderCount.regions, layerComposites and resamples, debug only), the window's editor
// body runs at most once, and the marquee's selection or the crop box shows on the overlay; the release lands the
// tool's result (a selection, the polygon's corners, a pending crop) as one step, as it does today. Nested in
// BodyCountSuites: it reads process-wide counters. `RenderBudgetPhotoOverlayDragTimingTests` (a perf suite,
// Tests/perf-suites.txt) runs the same drag with its release and holds each sample's step to the Move tool's p95
// bound of 4 ms on a release build (Tests/render-budgets.md). macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

/// The Photo tools whose canvas drag draws only an overlay mark until the release: every PhotoTool but the
/// pixel movers, the painters, and the tools that pick, type or draw paths.
enum OverlayDragger {
    /// Move moves a layer's pixels (PixelMover); brush, eraser, clone, heal, spot heal, remove, bucket and
    /// gradient lay new pixels; eyedropper picks a colour, text types and pen draws paths.
    static let excluded: Set<PhotoTool> = [
        .move, .brush, .eraser, .clone, .heal, .spotHeal, .remove, .bucket, .gradient, .eyedropper, .text, .pen,
    ]

    static var allCases: [PhotoTool] { PhotoTool.allCases.filter { !excluded.contains($0) } }

    /// A white one-layer image of `width` x `height` with `tool` chosen.
    static func model(_ tool: PhotoTool, width: Int, height: Int) throws -> PhotoWorkspace {
        var model = PhotoWorkspace()
        try model.newImage(DocumentSetup(width: Double(width), height: Double(height)))
        model.selectTool(tool)
        return model
    }

    /// Sample `i` of `samples` of the drag from `start`, in window points: 40 right, then 30 down, then back to
    /// 13 right and 20 down of the press, so the lasso encloses an area and a rectangle tool ends off its press.
    /// Small on purpose: the lasso's release rasterizes its box with 16 samples a pixel against every edge
    /// (CoreRaster's Mask.polygon), minutes on a debug build for a box of a few hundred thousand pixels.
    static func point(_ start: CGPoint, _ i: Int, of samples: Int) -> CGPoint {
        let leg = Double(samples) / 3, t = Double(i)
        let (dx, dy): (Double, Double) =
            t <= leg ? (40 * t / leg, 0)
            : t <= 2 * leg ? (40, 30 * (t - leg) / leg)
            : (40 - 27 * (t - 2 * leg) / leg, 30 - 10 * (t - 2 * leg) / leg)
        return CGPoint(x: start.x + dx, y: start.y + dy)
    }

    /// Whether the release landed `tool`'s result in `after`, from `before`.
    static func landed(_ tool: PhotoTool, _ after: PhotoWorkspace, from before: PhotoWorkspace) -> Bool {
        switch tool {
        case .polygon: after.areaDraft.count >= 2
        case .crop: after.pendingCrop != nil
        default: after.selection != nil && after.selection != before.selection
        }
    }

    /// The overlay element the drag shows while the pointer is down; nil for a tool whose draft has no probe
    /// (the ellipse's and lasso's AreaAnts draft, the polygon's corners) or shows nothing (the wand).
    static func mark(_ tool: PhotoTool) -> String? {
        switch tool {
        case .marquee: "photo.canvas.selection"
        case .crop: "photo.canvas.crop"
        default: nil
        }
    }

    /// Every region the canvas composited, layer laid onto one, and CPU resample in the process so far (debug only).
    static func pixels() -> Int {
        #if DEBUG
        PhotoRenderCount.regions.withLock { $0 } + PhotoRenderCount.layerComposites.withLock { $0 }
            + PhotoRenderCount.resamples.withLock { $0 }
        #else
        0
        #endif
    }

    /// Waits up to 90 s for the release to land (the wand floods 24 MP in a debug build); the workspace then.
    @MainActor static func landed(_ tool: PhotoTool, in edited: PhotoWindowEditedView, from before: PhotoWorkspace) async -> PhotoWorkspace? {
        for _ in 0..<4500 {
            if let shown = edited.workspace, landed(tool, shown, from: before) { return shown }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return edited.workspace
    }
}

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoOverlayDragTests {
        static let samples = 120

        @Test(.timeLimit(.minutes(5)), arguments: OverlayDragger.allCases)
        func overlayDraggerDoesNoPixelWorkUntilTheRelease(_ tool: PhotoTool) async throws {
            let model = try OverlayDragger.model(tool, width: 6000, height: 4000)
            let w = RenderBudgetWindow(PhotoWindow(model: model).allowsWindowActivationEvents())
            defer { w.close() }
            let edited = try await PixelMover.settle(w)
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
            let start = try #require(PixelMover.centre(of: w), "no canvas")
            let bodies = RenderBudgetPhotoTransformTests.bodies
            let (pixelsBefore, bodiesBefore) = (OverlayDragger.pixels(), bodies() ?? 0)
            var (pixelsDuring, bodiesDuring, shown) = (0, 0, true)
            let step = try await w.measure("photo \(tool.rawValue) drag, 24 MP, \(Self.samples) samples", bodies: bodies) {
                try await w.drag(from: start, samples: Self.samples, release: false) {
                    OverlayDragger.point(start, $0, of: Self.samples)
                }
                try await w.settle(200)
                pixelsDuring = OverlayDragger.pixels() - pixelsBefore
                bodiesDuring = (bodies() ?? 0) - bodiesBefore
                if let mark = OverlayDragger.mark(tool) { shown = await w.element(mark) != nil }
                w.timed { w.send(.leftMouseUp, at: OverlayDragger.point(start, Self.samples, of: Self.samples)) }
            }
            let after = try #require(await OverlayDragger.landed(tool, in: edited, from: model))
            #expect(OverlayDragger.landed(tool, after, from: model), "\(tool): the release landed nothing")
            #expect(shown, "\(tool): the overlay never showed the drag while the pointer was down")
            #if DEBUG
            #expect(pixelsDuring == 0, "\(tool): the drag composited \(pixelsDuring) regions before the release")
            #expect(bodiesDuring <= 1, "\(tool): the window's editor body ran \(bodiesDuring) times with the pointer down")
            #endif
            // The release adopts the copy and lands the step: one body for the gesture.
            expectBodies(step, atMost: 2, target: 1)
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
        }
    }
}

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoOverlayDragTimingTests {
        /// Every overlay dragger's drag on 24 MP: the Move tool's step bound.
        @Test(.timeLimit(.minutes(5)), arguments: OverlayDragger.allCases)
        func overlayDraggerStepIsUnder4MillisecondsOn24Megapixels(_ tool: PhotoTool) async throws {
            let model = try OverlayDragger.model(tool, width: 6000, height: 4000)
            let w = RenderBudgetWindow(PhotoWindow(model: model).allowsWindowActivationEvents())
            defer { w.close() }
            let edited = try await PixelMover.settle(w)
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
            let start = try #require(PixelMover.centre(of: w), "no canvas")
            let samples = RenderBudgetPhotoOverlayDragTests.samples
            let step = try await w.measure("photo \(tool.rawValue) drag, 24 MP", bodies: { nil }) {
                try await w.drag(from: start, samples: samples) { OverlayDragger.point(start, $0, of: samples) }
            }
            #expect(step.steps >= samples, "\(step)")
            expectP95(step, atMost: 4, target: 4)
            _ = await OverlayDragger.landed(tool, in: edited, from: model)
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
        }
    }
}
#endif
