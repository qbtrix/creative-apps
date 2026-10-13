// TiledPixels.swift: one layer's pixels on CoreRaster's tile grid
// (PixelBuffer.tileSize squares from the top left, the last column and row
// clipped), each tile its own PixelBuffer. Copies of a workspace share every
// tile and a write copies only the tiles it lands in, so a brush drag costs
// what its dabs touch however many copies are alive (SwiftUI's State keeps
// one). Tiles of one fill share a buffer until written. `flattened()` is the
// whole layer, for whole-image operations and tests, never per event.
// Invariants: `tiles` is row-major, `columns * rows` long, each tile the size
// of its `tileRect`. Linux-safe.
import CoreRaster

public struct TiledPixels: Sendable, Equatable {
    public let width: Int
    public let height: Int
    var tiles: [PixelBuffer]

    /// `buffer` cut into tiles.
    init(_ buffer: PixelBuffer) {
        width = buffer.width
        height = buffer.height
        var tiles: [PixelBuffer] = []
        for row in 0..<buffer.tileRows {
            for column in 0..<buffer.tileColumns {
                // Inside the grid by construction, so it can't throw.
                if let tile = try? buffer.tile(column: column, row: row) { tiles.append(tile) }
            }
        }
        self.tiles = tiles
    }

    /// `width` x `height` pixels of `fill`; tiles of one size share one buffer.
    /// Throws `RasterError` for a size or fill CoreRaster rejects.
    init(width: Int, height: Int, fill: RGBA = .clear) throws {
        _ = try PixelBuffer.validatedSize(width: width, height: height)
        self.width = width
        self.height = height
        var made: [PixelRect: PixelBuffer] = [:]
        tiles = []
        for i in 0..<(columns * rows) {
            let rect = tileRect(i), size = PixelRect(x: 0, y: 0, width: rect.width, height: rect.height)
            let tile = try made[size] ?? PixelBuffer(width: size.width, height: size.height, fill: fill)
            made[size] = tile
            tiles.append(tile)
        }
    }

    var columns: Int { max((width + PixelBuffer.tileSize - 1) / PixelBuffer.tileSize, 1) }
    var rows: Int { max((height + PixelBuffer.tileSize - 1) / PixelBuffer.tileSize, 1) }

    /// Tile `index`'s pixels in the layer.
    func tileRect(_ index: Int) -> PixelRect {
        let size = PixelBuffer.tileSize
        let x = index % columns * size, y = index / columns * size
        return PixelRect(x: x, y: y, width: min(size, width - x), height: min(size, height - y))
    }

    /// The tiles `rect` (layer pixels) overlaps, row-major.
    func tileIndices(in rect: PixelRect) -> [Int] {
        guard let area = rect.intersection(PixelRect(x: 0, y: 0, width: width, height: height)) else { return [] }
        let size = PixelBuffer.tileSize
        return ((area.y / size)...((area.maxY - 1) / size)).flatMap { row in
            ((area.x / size)...((area.maxX - 1) / size)).map { row * columns + $0 }
        }
    }

    /// The premultiplied pixel at (`x`, `y`). Throws `RasterError.invalid`
    /// outside the layer.
    public func pixel(x: Int, y: Int) throws -> RGBA {
        let size = PixelBuffer.tileSize
        let i = (y / size) * columns + x / size
        guard (0..<width).contains(x), (0..<height).contains(y), tiles.indices.contains(i) else {
            throw RasterError.invalid("pixel (\(x), \(y)) is outside \(width)x\(height)")
        }
        return try tiles[i].pixel(x: x % size, y: y % size)
    }

    /// The whole layer as one buffer.
    public func flattened() throws -> PixelBuffer {
        var whole = try PixelBuffer(width: width, height: height)
        for (i, tile) in tiles.enumerated() {
            try whole.replaceTile(column: i % columns, row: i / columns, with: tile)
        }
        return whole
    }
}
