// PhotoDocumentBytesTests.swift: the document's tile <-> byte conversion
// (TiledPixelsBytes.swift, PB-18 to PB-20) is bit for bit CoreRaster's
// `PixelBuffer(rgba8:)` and `rgba8()`: every byte value at every alpha,
// tiles cut across the grid's edges, and stored values on each side of every
// byte's rounding edge, past 0...1 and at tiny alphas. The box-filtered
// thumbnail keeps a flat color. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoDocumentBytesTests {
    /// Every r and g byte at every alpha, b mixed in, over 2 x 1 tiles.
    private func everyByte() -> DecodedImage {
        let width = 300, height = 256
        var bytes: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width {
                bytes += [UInt8(x % 256), UInt8(255 - x % 256), UInt8((x * 7 + y) % 256), UInt8(y)]
            }
        }
        return DecodedImage(rgba8: bytes, width: width, height: height)
    }

    @Test func bytesToTilesMatchCoreRaster() throws {
        let image = everyByte()
        let tiles = try TiledPixels(rgba8: image.rgba8, width: image.width, height: image.height)
        #expect(tiles == TiledPixels(try PixelBuffer(rgba8: image.rgba8, width: image.width, height: image.height)))
        #expect(try tiles.rgba8() == tiles.flattened().rgba8())
    }

    @Test func flatTilesMatchCoreRaster() throws {
        // Clear and one color tiles, then one with a single different pixel.
        var bytes = Array(repeating: [UInt8](arrayLiteral: 0, 0, 0, 0), count: 300 * 260).flatMap { $0 }
        for i in stride(from: 300 * 4 * 256, to: bytes.count, by: 4) { bytes[i] = 200; bytes[i + 1] = 9; bytes[i + 3] = 128 }
        bytes[(10 * 300 + 270) * 4] = 1
        let tiles = try TiledPixels(rgba8: bytes, width: 300, height: 260)
        let engine = try PixelBuffer(rgba8: bytes, width: 300, height: 260)
        #expect(tiles == TiledPixels(engine))
        #expect(try tiles.rgba8() == engine.rgba8())
    }

    @Test func tilesToBytesMatchCoreRasterAtEveryRoundingEdge() throws {
        var values: [Float] = [0, -0.0, -1, 1, 1.5, .greatestFiniteMagnitude, -.greatestFiniteMagnitude]
        for edge in SRGBBytes.least { values += [edge.nextDown, edge, edge.nextUp] }
        let alphas: [Float] = [1, 0.5, 0.003, 1e-30, 0.999, 2, -0.25]
        let width = 257, rows = (values.count + width - 1) / width
        var buffer = try PixelBuffer(width: width, height: rows * alphas.count)
        for (row, alpha) in alphas.enumerated() {
            func stored(_ i: Int) -> Float {
                let v = values[i % values.count]
                return (v * alpha).isFinite ? v * alpha : v
            }
            for i in values.indices {
                try buffer.setPixel(x: i % width, y: row * rows + i / width,
                                    RGBA(r: stored(i), g: stored(i + 1), b: stored(i + 2), a: alpha))
            }
        }
        #expect(try SRGBBytes.bytes(of: buffer) == buffer.rgba8())
        #expect(try TiledPixels(buffer).rgba8() == buffer.rgba8())
    }

    @Test func thumbnailOfAFlatColorIsThatColor() throws {
        let flat = DecodedImage(rgba8: Array(repeating: [10, 200, 77, 255], count: 600 * 450).flatMap { $0 },
                                width: 600, height: 450)
        let thumb = try #require(try SRGBBytes.thumbnail(flat, width: 256, height: 192))
        #expect(thumb.width == 256 && thumb.height == 192)
        #expect(thumb.rgba8 == Array(repeating: [10, 200, 77, 255], count: 256 * 192).flatMap { $0 })
    }

    @Test func refusesTheWrongByteCount() {
        #expect(throws: RasterError.self) { try TiledPixels(rgba8: [0, 0, 0], width: 1, height: 1) }
    }
}
