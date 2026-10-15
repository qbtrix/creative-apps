// TiledPixelsBytes.swift: a layer's tiles to and from 8-bit straight-alpha
// sRGB bytes, as a document keeps them (PB-18 to PB-20 of photo-documents),
// tile by tile across the cores, bit for bit CoreRaster's `rgba8()` and
// `PixelBuffer(rgba8:)`. Its sRGB curve is per channel, so both directions
// read tables built from CoreRaster itself, not a curve per pixel: decoding
// looks each byte's linear value up; encoding finds the byte among the least
// values CoreRaster rounds to each byte (curve and rounding only rise). A
// one-color tile decodes as a fill and a run of one pixel encodes once.
// `thumbnail` is a box filter in linear light. Linux-safe.
import CoreRaster

extension TiledPixels {
    /// `rgba8` (width x height x 4 straight sRGB bytes) in tiles; equal to
    /// `TiledPixels(PixelBuffer(rgba8:width:height:))`. Throws
    /// `RasterError.invalid` for a size or byte count CoreRaster rejects.
    init(rgba8 bytes: [UInt8], width: Int, height: Int) throws {
        let pixels = try PixelBuffer.validatedSize(width: width, height: height)
        guard bytes.count == pixels * 4 else {
            throw RasterError.invalid("rgba8 has \(bytes.count) bytes; \(width)x\(height) needs \(pixels * 4)")
        }
        var layer = try TiledPixels(width: width, height: height)
        let grid = layer
        layer.tiles = try PhotoLayerComposite.inParallel(grid.tiles.count) { i in
            try SRGBBytes.tile(grid.tileRect(i), of: bytes, width: width)
        }
        self = layer
    }

    /// The layer as width x height x 4 straight sRGB bytes; equal to
    /// `flattened().rgba8()`.
    func rgba8() throws -> [UInt8] {
        let grid = self
        let pieces = try PhotoLayerComposite.inParallel(tiles.count) { i in try SRGBBytes.bytes(of: grid.tiles[i]) }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for (i, piece) in pieces.enumerated() {
            let rect = tileRect(i), row = rect.width * 4
            guard piece.count == row * rect.height else { throw RasterError.invalid("tile \(i) is the wrong size") }
            for y in 0..<rect.height {
                let to = ((rect.y + y) * width + rect.x) * 4
                bytes.replaceSubrange(to..<(to + row), with: piece[(y * row)..<((y + 1) * row)])
            }
        }
        return bytes
    }
}

enum SRGBBytes {
    /// `linear[b]`: the linear value CoreRaster decodes sRGB byte b to.
    static let linear: [Float] = (0...255).map { b in
        let byte = UInt8(b)
        return (try? PixelBuffer(rgba8: [byte, byte, byte, 255], width: 1, height: 1).pixel(x: 0, y: 0).r) ?? 0
    }

    /// `least[k - 1]`, k in 1...255: the least Float CoreRaster encodes as a
    /// byte of at least k. Found by bisecting the Float bit patterns of 0...1,
    /// whose order is their values' order.
    static let least: [Float] = (1...255).map { k in
        var below = Float(0).bitPattern, atOrAbove = Float(1).bitPattern
        while atOrAbove - below > 1 {
            let mid = below + (atOrAbove - below) / 2
            let v = Float(bitPattern: mid)
            let byte = try? PixelBuffer(width: 1, height: 1, fill: RGBA(r: v, g: v, b: v, a: 1)).rgba8().first
            if Int(byte ?? 0) >= k { atOrAbove = mid } else { below = mid }
        }
        return Float(bitPattern: atOrAbove)
    }

    /// `start[j]`: the byte of j / 4096, where the search for a value in
    /// that bucket starts.
    static let start: [UInt8] = (0...buckets).map { j in
        UInt8(least.lazy.filter { $0 <= Float(j) / Float(buckets) }.count)
    }

    static let buckets = 4096

    /// The byte for the straight component `value`: how many of `least` it
    /// reaches, counted on from its bucket's start. Past 0...1 it clamps.
    @inline(__always)
    static func byte(_ value: Float, least: [Float], start: [UInt8]) -> UInt8 {
        guard value > 0 else { return 0 }
        guard value < 1 else { return 255 }
        // value * 4096 is exact, so the bucket's low end is at most value.
        var k = Int(start[Int(value * Float(buckets))])
        while k < least.count, value >= least[k] { k += 1 }
        return UInt8(k)
    }

    /// The pixel CoreRaster decodes the 4 bytes at `at` to.
    @inline(__always)
    static func pixel(_ bytes: [UInt8], at: Int, linear: [Float]) -> RGBA {
        let alpha = Float(bytes[at + 3]) / 255
        return RGBA(r: linear[Int(bytes[at])] * alpha, g: linear[Int(bytes[at + 1])] * alpha,
                    b: linear[Int(bytes[at + 2])] * alpha, a: alpha)
    }

    /// The pixels of `rect` in `bytes`, a layer `width` pixels wide, as one
    /// tile. A tile of one color (often clear) is a fill.
    static func tile(_ rect: PixelRect, of bytes: [UInt8], width: Int) throws -> PixelBuffer {
        let linear = Self.linear, first = (rect.y * width + rect.x) * 4
        let flat = (0..<rect.height).allSatisfy { y in
            let row = ((rect.y + y) * width + rect.x) * 4
            return (0..<(rect.width * 4)).allSatisfy { bytes[row + $0] == bytes[first + $0 % 4] }
        }
        if flat { return try PixelBuffer(width: rect.width, height: rect.height, fill: pixel(bytes, at: first, linear: linear)) }
        var tile = try PixelBuffer(width: rect.width, height: rect.height)
        for y in 0..<rect.height {
            var at = ((rect.y + y) * width + rect.x) * 4
            for x in 0..<rect.width {
                try tile.setPixel(x: x, y: y, pixel(bytes, at: at, linear: linear))
                at += 4
            }
        }
        return tile
    }

    /// `tile.rgba8()`, through the tables; a run of one pixel converts once.
    static func bytes(of tile: PixelBuffer) throws -> [UInt8] {
        let least = Self.least, start = Self.start
        var bytes = [UInt8](repeating: 0, count: tile.width * tile.height * 4)
        var at = 0, last = RGBA.clear, encoded: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0)
        for y in 0..<tile.height {
            for x in 0..<tile.width {
                let p = try tile.pixel(x: x, y: y)
                // Equal components give equal bytes (0 and -0 both give 0).
                if p != last {
                    last = p
                    // As `RGBA.unpremultiplied`: no color at alpha 0.
                    encoded = p.a == 0 ? (0, 0, 0, 0) : (
                        byte(p.r / p.a, least: least, start: start), byte(p.g / p.a, least: least, start: start),
                        byte(p.b / p.a, least: least, start: start),
                        UInt8((min(max(Double(p.a), 0), 1) * 255).rounded()))
                }
                bytes[at] = encoded.0; bytes[at + 1] = encoded.1
                bytes[at + 2] = encoded.2; bytes[at + 3] = encoded.3
                at += 4
            }
        }
        return bytes
    }

    /// `image` (straight sRGB bytes) at `width` x `height`, each pixel the
    /// mean of the source pixels under it in premultiplied linear light;
    /// nil unless both sides shrink.
    static func thumbnail(_ image: DecodedImage, width: Int, height: Int) throws -> DecodedImage? {
        let w = image.width, h = image.height, bytes = image.rgba8, linear = Self.linear
        guard width >= 1, height >= 1, width <= w, height <= h, bytes.count == w * h * 4 else { return nil }
        let rows = try PhotoLayerComposite.inParallel(height) { oy in
            let y0 = oy * h / height, y1 = (oy + 1) * h / height
            return (0..<width).map { ox in
                let x0 = ox * w / width, x1 = (ox + 1) * w / width
                var r = 0.0, g = 0.0, b = 0.0, a = 0.0
                for y in y0..<y1 {
                    for x in x0..<x1 {
                        let p = pixel(bytes, at: (y * w + x) * 4, linear: linear)
                        r += Double(p.r); g += Double(p.g); b += Double(p.b); a += Double(p.a)
                    }
                }
                // x1 > x0 and y1 > y0: each side shrinks, so every box holds a pixel.
                let n = Double(max((x1 - x0) * (y1 - y0), 1))
                return RGBA(r: Float(r / n), g: Float(g / n), b: Float(b / n), a: Float(a / n))
            }
        }
        var small = try PixelBuffer(width: width, height: height)
        for (y, row) in rows.enumerated() {
            for (x, pixel) in row.enumerated() { try small.setPixel(x: x, y: y, pixel) }
        }
        return DecodedImage(rgba8: try small.rgba8(), width: width, height: height)
    }
}
