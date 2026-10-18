// PhotoZoomSweepTests.swift: what panning an 8K Photo document costs at each
// zoom, on each render backend, through the real display path (report only,
// no budget yet). The document is PhotoRenderBudgetTests' 7680 x 4320 one with
// three layers. Per backend (CoreRender's CPU backend, and Metal on this Mac's
// GPU when there is one) a CanvasRenderer on that route draws the picture
// into PhotoEditor's tile canvas, hosted in RenderBudgetWindow's off-screen
// 1280 x 820 window. At 25, 50, 75, 100, 150, 200, 300 and 400 % it times:
//   - first draw: from setting the zoom until the tile view is laid out at the
//     new size, plus the layout, display and Core Animation commit that forced;
//   - pan frames: the canvas's scroll view moved 12 pt per frame on both axes
//     (back and forth inside its range) at 120 Hz, each frame timed as the
//     scroll, layout, display and commit it forced.
// It drives the canvas's NSScrollView directly, as the harness's scroll does:
// a wheel event made in a test has no phase. Only the main thread's share is
// timed, not the window server's compositing.
// Report: one PHOTO-ZOOM-SWEEP line per backend and zoom, also in
// .build/snapshots/photo-zoom-sweep.txt. In Tests/perf-suites.txt, so the
// merge gate skips it; it asserts no time. macOS only.
#if canImport(AppKit)
import AppKit
import CoreRenderMetal
import Observation
import PhotoModel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteUI

@MainActor @Suite(.serialized) struct PhotoZoomSweepTests {
    static let zooms: [Double] = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4]
    static let config = PhotoRenderBudgetTests.config
    /// Pan frames per zoom; a debug build's 8K picture takes minutes per backend, so it pans less.
    static let frames = config == "release" ? 120 : 30
    static let step = 12.0

    @Test(.timeLimit(.minutes(15))) func panAndFirstDrawAtEachZoomOnEachBackend() async throws {
        var routes: [(String, PhotoRenderRoute)] = [("CPU", .cpu)]
        if let device = MetalBackend.defaultDevice {
            routes.append(("GPU", PhotoRenderRoute(preferred: try MetalBackend(device: device, cacheURL: nil))))
        }
        let workspace = try PhotoRenderBudgetTests.document()
        let width = Double(try #require(workspace.canvas).width)
        var lines: [String] = []
        for (label, route) in routes {
            let renderer = CanvasRenderer()
            renderer.use(route)
            renderer.show(workspace)
            let zoom = SweepZoom()
            let w = RenderBudgetWindow(ZoomSweepEditor(model: workspace, tiles: renderer.tiles, zoom: zoom))
            defer { w.close() }
            let deadline = ContinuousClock.now + .seconds(600)
            while renderer.revision != workspace.revision, ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(50))
            }
            try #require(renderer.revision == workspace.revision, "\(label): the first picture never landed")
            let canvas = try #require(await w.first(TileCanvasView.self), "\(label): no tile canvas")
            let scroll = try #require(canvas.enclosingScrollView ?? w.scrollView(at: CGPoint(x: 640, y: 410)))
            try await w.settle(500)

            for z in Self.zooms {
                let firstDraw = try await Self.firstDraw(at: z, width: width, zoom: zoom, canvas: canvas, window: w)
                try await w.settle(200)
                let pan = try await Self.pan(scroll, window: w)
                let line = String(
                    format: "PHOTO-ZOOM-SWEEP %@ %@ zoom %d%%: pan p50 %.2f ms, pan p95 %.2f ms, pan max %.2f ms, first draw %.1f ms (%d frames over %.0fx%.0f pt%@)",
                    label, Self.config, Int((z * 100).rounded()), pan.p50, pan.p95, pan.max,
                    firstDraw ?? -1, pan.count, pan.range.width, pan.range.height,
                    firstDraw == nil ? ", the canvas never reached the zoom" : "")
                print(line)
                lines.append(line)
                #expect(firstDraw != nil, "\(line)")
            }
        }
        let folder = URL(fileURLWithPath: ".build/snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try (lines.joined(separator: "\n") + "\n").write(
            to: folder.appendingPathComponent("photo-zoom-sweep.txt"), atomically: true, encoding: .utf8)
    }

    /// Milliseconds from setting `z` until the tile view is `width * z` points wide and that frame is committed;
    /// nil when it never gets there in 5 s.
    static func firstDraw(
        at z: Double, width: Double, zoom: SweepZoom, canvas: NSView, window w: RenderBudgetWindow<ZoomSweepEditor>
    ) async throws -> Double? {
        let clock = ContinuousClock()
        let began = clock.now
        zoom.value = z
        while clock.now - began < .seconds(5) {
            commit(w)
            if abs(canvas.bounds.width - width * z) <= max(1, width * z * 0.001) {
                return milliseconds(clock.now - began)
            }
            try await Task.sleep(for: .milliseconds(1))
        }
        return nil
    }

    /// `frames` pan frames at 120 Hz, 12 pt a frame on each axis, folded back and forth inside the scroll range.
    static func pan(
        _ scroll: NSScrollView, window w: RenderBudgetWindow<ZoomSweepEditor>
    ) async throws -> (p50: Double, p95: Double, max: Double, count: Int, range: CGSize) {
        let clip = scroll.contentView
        let document = scroll.documentView?.frame.size ?? .zero
        let range = CGSize(
            width: max(document.width - clip.bounds.width, 0), height: max(document.height - clip.bounds.height, 0))
        let start = CGPoint(x: range.width / 2, y: range.height / 2)
        let clock = ContinuousClock()
        let began = clock.now
        var times: [Double] = []
        for i in 1...frames {
            try await Task.sleep(until: began + .microseconds(8_333 * i), clock: clock)
            let frame = clock.now
            let moved = step * Double(i)
            clip.scroll(to: NSPoint(x: fold(start.x + moved, range.width), y: fold(start.y + moved, range.height)))
            scroll.reflectScrolledClipView(clip)
            commit(w)
            times.append(milliseconds(clock.now - frame))
        }
        let sorted = times.sorted()
        return (
            SuiteFrameProbe.nearestRank(sorted, 0.5) ?? 0, SuiteFrameProbe.nearestRank(sorted, 0.95) ?? 0,
            sorted.last ?? 0, sorted.count, range
        )
    }

    /// The layout and display the last change forced, and the Core Animation commit that hands it on.
    static func commit(_ w: RenderBudgetWindow<ZoomSweepEditor>) {
        w.host.layoutSubtreeIfNeeded()
        w.window.displayIfNeeded()
        CATransaction.flush()
    }

    /// `value` bounced back and forth inside 0...`limit`.
    static func fold(_ value: Double, _ limit: Double) -> Double {
        guard limit > 0 else { return 0 }
        let r = value.truncatingRemainder(dividingBy: 2 * limit)
        return r <= limit ? r : 2 * limit - r
    }

    static func milliseconds(_ d: Duration) -> Double { Double(d / .microseconds(1)) / 1000 }
}

/// The zoom the sweep sets; the editor follows it as the window's own zoom state.
@MainActor @Observable final class SweepZoom {
    var value = 1.0
}

/// The Photo editor at the sweep's zoom, showing the renderer's tiles.
struct ZoomSweepEditor: View {
    let model: PhotoWorkspace
    let tiles: CanvasTiles
    let zoom: SweepZoom

    var body: some View {
        PhotoEditor(model: model, tiles: tiles, zoom: zoom.value)
    }
}
#endif
