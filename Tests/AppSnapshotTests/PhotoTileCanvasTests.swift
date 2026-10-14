// PhotoTileCanvasTests.swift: the tile layers show the reference picture.
// TileCanvasView's layers, rendered by Core Animation, equal the CPU
// reference (PhotoRenderer.render, premultiplied) at zoom 1, the right way up;
// at zooms that put tile edges between pixels an opaque image stays opaque
// everywhere, so abutting tiles leave no seam; and `cacheDisplay`, which the
// snapshots use, draws what the layers show. macOS only.
import AppKit
import CoreRaster
import PhotoModel
import Testing

@testable import PhotoApp

@MainActor @Suite struct PhotoTileCanvasTests {
    /// A 600 x 520 opaque image, 3 x 3 tiles, with a stroke across tile edges.
    func workspace() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 600, height: 520)
        workspace.setToolOption(.color(red: 200, green: 40, blue: 90))
        workspace.selectTool(.brush)
        workspace.drag(from: Mask.Point(x: 30, y: 400), to: Mask.Point(x: 30, y: 400))
        workspace.drag(from: Mask.Point(x: 30, y: 400), to: Mask.Point(x: 560, y: 60))
        workspace.endDrag()
        return workspace
    }

    /// The view at `zoom` showing `workspace`'s tiles.
    func view(_ workspace: PhotoWorkspace, zoom: Double) throws -> TileCanvasView {
        let tiles = try #require(try CanvasTiles.complete(workspace))
        let view = TileCanvasView(frame: CGRect(x: 0, y: 0, width: 600 * zoom, height: 520 * zoom))
        view.configure(zoom: zoom, degrees: 0)
        tiles.attach(view)
        view.layoutSubtreeIfNeeded()
        return view
    }

    /// `draw` into a premultiplied sRGB bitmap of `size`, top row first.
    func pixels(_ size: CGSize, _ draw: (CGContext) -> Void) throws -> [UInt8] {
        let (w, h) = (Int(size.width), Int(size.height))
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try bytes.withUnsafeMutableBytes { raw in
            let context = try #require(
                CGContext(
                    data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            draw(context)
        }
        return bytes
    }

    @Test func theLayersAtZoomOneAreTheReference() async throws {
        let workspace = try workspace()
        let view = try view(workspace, zoom: 1)
        let layer = try #require(view.layer)
        let shown = try pixels(view.bounds.size) { layer.render(in: $0) }
        let reference = PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8)
        let worst = zip(shown, reference).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(worst <= 1, "layers differ from the reference by up to \(worst)")
    }

    @Test(arguments: [0.37, 0.5, 1.3, 2.5]) func tileEdgesLeaveNoSeam(zoom: Double) throws {
        let view = try view(try workspace(), zoom: zoom)
        let layer = try #require(view.layer)
        let size = CGSize(width: (600 * zoom).rounded(.down), height: (520 * zoom).rounded(.down))
        let shown = try pixels(size) { layer.render(in: $0) }
        let holes = stride(from: 3, to: shown.count, by: 4).filter { shown[$0] < 255 }.count
        #expect(holes == 0, "\(holes) pixels see through the picture at zoom \(zoom)")
    }

    @Test func cacheDisplayDrawsWhatTheLayersShow() throws {
        let view = try view(try workspace(), zoom: 1)
        let layer = try #require(view.layer)
        let shown = try pixels(view.bounds.size) { layer.render(in: $0) }
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let cached = try #require(rep.cgImage)
        let drawn = try pixels(view.bounds.size) { $0.draw(cached, in: CGRect(origin: .zero, size: view.bounds.size)) }
        let worst = zip(shown, drawn).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(worst <= 2, "cacheDisplay differs from the layers by up to \(worst)")
        #expect(drawn.count == shown.count && stride(from: 3, to: drawn.count, by: 4).allSatisfy { drawn[$0] == 255 })
    }
}
