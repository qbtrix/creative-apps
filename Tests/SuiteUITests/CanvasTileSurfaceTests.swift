// CanvasTileSurfaceTests.swift: a tile's IOSurface holds its premultiplied
// sRGB bytes as BGRA, tagged sRGB, and the host's tile layer shows that
// surface in place of the image (Core Animation draws a surface as it is; it
// colour-converts an sRGB image on the main thread at each commit). macOS only.
import AppKit
import IOSurface
import Testing

@testable import SuiteUI

@MainActor
@Suite struct CanvasTileSurfaceTests {
    @Test func aSurfaceHoldsTheBytesAsBGRATaggedSRGB() throws {
        let bytes: [UInt8] = [10, 20, 30, 255, 40, 50, 60, 128, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
        let surface = try #require(CanvasTile.surface(premultipliedRGBA: bytes, width: 3, height: 2))
        #expect(surface.width == 3 && surface.height == 2)
        surface.lock(options: .readOnly, seed: nil)
        defer { surface.unlock(options: .readOnly, seed: nil) }
        var read: [UInt8] = []
        for y in 0..<2 {
            let row = surface.baseAddress.advanced(by: y * surface.bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<3 { read += [row[x * 4 + 2], row[x * 4 + 1], row[x * 4], row[x * 4 + 3]] }
        }
        #expect(read == bytes)
        #expect(IOSurfaceCopyValue(surface, kIOSurfaceColorSpace) != nil)
        #expect(CanvasTile.surface(premultipliedRGBA: [1, 2, 3], width: 3, height: 2) == nil)
    }

    @Test func aTileLayerShowsItsSurfaceInPlaceOfItsImage() throws {
        let canvas = CanvasHostView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let rect = CanvasTileRect(x: 0, y: 0, width: 2, height: 2)
        let bytes = [UInt8](repeating: 200, count: 16)
        let surface = try #require(CanvasTile.surface(premultipliedRGBA: bytes, width: 2, height: 2))
        canvas.show(Content(tiles: [CanvasTile(rect: rect, image: nil, surface: surface)]))
        let layer = try #require(canvas.container.sublayers?.first)
        #expect((layer.contents as AnyObject?) === surface)
        #expect(canvas.shown().first?.surface === surface)
    }

    struct Content: CanvasContentProviding {
        let tiles: [CanvasTile]
        var documentSize: CGSize { CGSize(width: 2, height: 2) }
        func tiles(dirtyOnly: Bool) -> [CanvasTile] { tiles }
    }
}
