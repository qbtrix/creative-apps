// PhotoRenderBudgetTests.swift: what an 8K Photo document costs to draw on
// each backend, recorded and not yet held to a budget (the large-image gate,
// beta-80 row G1, sets those). The document is 7680 x 4320 with three
// layers: the white Background, a full-canvas fill at 50 % and a Paint layer
// with one brush stroke. Per backend (CoreRender's CPU backend, and Metal on
// this Mac's GPU when there is one, with and without resident layer tiles)
// it times the first picture of the document, a full picture and a brush
// frame (one 64 px brush segment's damaged tiles, the median of 10; a debug
// build times one full picture and 4 frames). GPU-resident keeps the layer
// tiles on the GPU and writes the picture into a texture, as the canvas's
// presenter takes it, so nothing is read back; its first picture uploads
// every layer tile and its line counts them,
// both through PhotoRenderer.update, which is all the live canvas renders. A
// pan renders nothing on either backend: the canvas moves the tiles it has.
// Report: one PHOTO-RENDER-8K line per backend in
// .build/snapshots/photo-render-budget.txt. The document autosaves into a temp
// folder, never the user's. In Tests/perf-suites.txt, so the merge gate skips
// it. PhotoFlipCanvasBudgetTests (OC-14, in BodyCountSuites): Flip Canvas on an
// 8K two-layer window takes at most 2 window bodies. macOS only.
import CoreRaster
import CoreRender
import CoreRenderMetal
import Foundation
import Metal
import PhotoModel
import Testing

@testable import PhotoApp

@Suite(.serialized) struct PhotoRenderBudgetTests {
    /// The optimizer's setting, not the DEBUG flag: an optimized run built with -DDEBUG (so the
    /// suite's debug-only counters compile) still times as release.
    static let config = _isDebugAssertConfiguration() ? "debug" : "release"

    /// Live services with autosaves in a temp folder: PhotoZoomBudgetTests hosts this document in a
    /// real window, whose autosave would otherwise land in the user's recovery folder.
    static let services = PhotoServices.live.recovering(
        in: FileManager.default.temporaryDirectory.appending(path: "PhotoRenderBudget-Recovery", directoryHint: .isDirectory))

    /// The 8K document, Paint selected with the brush ready.
    static func document() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace(services: services)
        try workspace.newCanvas(width: 7680, height: 4320)
        workspace.addLayer()
        workspace.setToolOption(.color(red: 30, green: 120, blue: 210))
        workspace.selectAll()
        workspace.fillSelection()
        workspace.deselect()
        workspace.setOpacity(try #require(workspace.selectedLayerID), percent: 50)
        workspace.addLayer()
        workspace.selectTool(.brush)
        workspace.setToolOption(.size(64))
        workspace.setToolOption(.color(red: 220, green: 40, blue: 60))
        workspace.drag(from: Mask.Point(x: 1000, y: 1000), to: Mask.Point(x: 1000, y: 1000))
        workspace.drag(from: Mask.Point(x: 1000, y: 1000), to: Mask.Point(x: 6000, y: 3000))
        workspace.endDrag()
        return workspace
    }

    /// A debug build runs CoreRaster's and the Metal backend's per-pixel loops about 20x slower, so it times once.
    static let fullRuns = config == "release" ? 3 : 1
    static let brushRuns = config == "release" ? 10 : 4

    static func median(_ values: [Double]) -> Double { values.sorted()[values.count / 2] }

    /// A canvas-sized rgba8 texture on `metal`'s device and a display target writing into it (with a tone
    /// program too), as the canvas host's presenter texture takes the resident path's picture.
    static func textureTarget(_ metal: MetalBackend, width: Int, height: Int) throws -> PhotoDisplayTarget {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        let held = BudgetTexture(texture: try #require(metal.device.makeTexture(descriptor: descriptor)))
        return PhotoDisplayTarget(
            write: { surface, rect in
                try metal.display(surface, into: held.texture, x: rect.x, y: rect.y, colorSpace: .sRGB, premultiplied: true)
            },
            writeToned: { surface, rect, tone in
                try metal.display(
                    surface, into: held.texture, x: rect.x, y: rect.y, colorSpace: .sRGB, premultiplied: true, tone: tone)
            })
    }

    @Test(.timeLimit(.minutes(15))) func eightKFullPictureAndBrushFrameOnEachBackend() async throws {
        // label, route, a fresh route for the cold picture (resident: new tiles, warm pipelines), target
        var routes: [(String, PhotoRenderRoute, () -> PhotoRenderRoute, PhotoDisplayTarget?)] = [("CPU", .cpu, { .cpu }, nil)]
        if let device = MetalBackend.defaultDevice {
            let metal = try MetalBackend(device: device, cacheURL: nil)
            routes.append(("GPU", PhotoRenderRoute(preferred: metal), { PhotoRenderRoute(preferred: metal) }, nil))
            let fresh = { PhotoRenderRoute(preferred: metal, resident: ResidentSurfaces(backend: metal)) }
            routes.append(("GPU-resident", fresh(), fresh, try Self.textureTarget(metal, width: 7680, height: 4320)))
        }
        var lines: [String] = []
        for (label, warmRoute, freshRoute, target) in routes {
            var workspace = try Self.document()
            // In release a first, untimed picture warms the pipelines and the caches.
            if Self.fullRuns > 1 { _ = try await PhotoRenderer.update(workspace, since: nil, route: warmRoute, target: target) }
            // The first picture of a document just opened: every layer tile goes up on the resident route.
            let route = freshRoute()
            let cold = try await PhotoRenderer.update(workspace, since: nil, route: route, target: target)
            var full: [Double] = []
            var shown = cold.revision
            for _ in 0..<Self.fullRuns {
                let update = try await PhotoRenderer.update(workspace, since: nil, route: route, target: target)
                full.append(update.milliseconds)
                shown = update.revision
                #expect(update.backend == (route.preferred?.name ?? "cpu"))
                #expect(update.wroteTarget == (target != nil))
            }
            let uploads = route.resident?.uploads
            var brush: [Double] = []
            var tiles = 0
            for i in 0..<Self.brushRuns {
                let x = 2000 + Double(i) * 48
                workspace.drag(from: Mask.Point(x: x, y: 2000), to: Mask.Point(x: x + 48, y: 2010))
                let update = try await PhotoRenderer.update(workspace, since: shown, route: route, target: target)
                brush.append(update.milliseconds)
                tiles = max(tiles, PhotoRenderer.tiles(of: try #require(workspace.canvas), in: workspace.damage(since: shown)).count)
                shown = update.revision
            }
            workspace.endDrag()
            let brushUploads = (route.resident?.uploads).map { $0 - (uploads ?? 0) }
            let line = String(
                format: "PHOTO-RENDER-8K %@ %@ (%@): first picture %.0f ms, full picture median %.0f ms (%@), brush frame median %.1f ms p-max %.1f ms (up to %d tiles)%@",
                label, Self.config, route.preferred?.name ?? "cpu", cold.milliseconds, Self.median(full),
                full.map { String(format: "%.0f", $0) }.joined(separator: " / "), Self.median(brush),
                brush.max() ?? 0, tiles,
                uploads.map { ", \($0) layer tiles uploaded once, \(brushUploads ?? 0) over \(Self.brushRuns) brush frames" } ?? "")
            print(line)
            lines.append(line)
        }
        let folder = URL(fileURLWithPath: ".build/snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try (lines.joined(separator: "\n") + "\n").write(
            to: folder.appendingPathComponent("photo-render-budget.txt"), atomically: true, encoding: .utf8)
    }
}

extension BodyCountSuites {
    @MainActor @Suite struct PhotoFlipCanvasBudgetTests {
        /// Image > Flip Canvas Horizontal on an 8K two-layer image: one undo step, at most 2 window bodies.
        @Test(.timeLimit(.minutes(2))) func flipCanvasInOneBody() async throws {
            let w = RenderBudgetWindow(PhotoWindow(model: try Self.document()))
            defer { w.close() }
            let bodies = { BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(1000)
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let send = try #require(edited.send)
            let step = try await w.measure("photo flip canvas horizontal, 8K, two layers", bodies: bodies) {
                send(.flipCanvas(.horizontal))
                try await w.settle(1500)
            }
            #expect(edited.workspace?.undoActionName == "Undo Flip Horizontal", "Flip Canvas Horizontal made no Flip Horizontal step")
            expectBodies(step, atMost: 2, target: 1)
        }

        /// 7680 x 4320: the white Background and a full-canvas fill above it.
        static func document() throws -> PhotoWorkspace {
            var workspace = PhotoWorkspace(services: PhotoRenderBudgetTests.services)
            try workspace.newCanvas(width: 7680, height: 4320)
            workspace.addLayer()
            workspace.setToolOption(.color(red: 30, green: 120, blue: 210))
            workspace.selectAll()
            workspace.fillSelection()
            workspace.deselect()
            return workspace
        }
    }
}

/// The resident target's texture, carried into the render tasks; Metal textures are thread-safe.
private struct BudgetTexture: @unchecked Sendable {
    let texture: any MTLTexture
}
