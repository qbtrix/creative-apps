// TiledPixels.swift: one layer's pixels on CoreRaster's tile grid
// (PixelBuffer.tileSize squares from the top left, the last column and row
// clipped), each tile its own PixelBuffer. Copies of a workspace share every
// tile and a write copies only the tiles it lands in, so a brush drag costs
// what its dabs touch however many copies are alive (SwiftUI's State keeps
// one). Tiles of one fill share a buffer until written. `flattened()` is the
// whole layer, for whole-image operations and tests, never per event.
// `paintedBounds` is the box of its pixels with alpha above 0 (Free
// Transform's box), skipping tiles that share a clear buffer; `replace`
// writes a buffer over part of the layer, touching only the tiles under it.
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

    /// The smallest rectangle (layer pixels) holding every pixel with alpha
    /// above 0 inside `window` (layer pixels; nil reads the whole layer); nil
    /// when that part is clear. Each tile is `PhotoLayerComposite.paintedRect`'s
    /// scan, except a tile equal to a clear tile already seen: one fill's tiles
    /// share a buffer, so a brush layer's untouched tiles cost one compare each.
    /// ponytail: a clear tile that shares no buffer is still read in full; an
    /// edge-inward tile walk is the upgrade if a big, mostly clear layer is slow.
    func paintedBounds(in window: PixelRect? = nil) throws -> PixelRect? {
        let whole = PixelRect(x: 0, y: 0, width: width, height: height)
        guard let area = (window ?? whole).intersection(whole) else { return nil }
        var clear: [PixelBuffer] = [], found: PixelRect?
        for i in tileIndices(in: area) where tiles.indices.contains(i) {
            let tile = tiles[i], rect = tileRect(i)
            if clear.contains(tile) { continue }
            guard let painted = try PhotoLayerComposite.paintedRect(of: tile, in: area.offsetBy(-rect.x, -rect.y))
            else {
                if area.intersection(rect) == rect { clear.append(tile) }
                continue
            }
            let r = painted.offsetBy(rect.x, rect.y)
            found = found?.union(r) ?? r
        }
        return found
    }

    /// `buffer` written exactly over these pixels with its top-left at (`x`,
    /// `y`) (layer pixels), clipped to the layer. Only the tiles under it are
    /// written; a tile it covers whole becomes its crop, the rest pixel by pixel.
    mutating func replace(with buffer: PixelBuffer, x: Int, y: Int) throws {
        let placed = PixelRect(x: x, y: y, width: buffer.width, height: buffer.height)
        for i in tileIndices(in: placed) where tiles.indices.contains(i) {
            let rect = tileRect(i)
            guard let part = placed.intersection(rect) else { continue }
            if part == rect {
                tiles[i] = try buffer.cropped(x: part.x - x, y: part.y - y, width: part.width, height: part.height)
                continue
            }
            for py in part.y..<part.maxY {
                for px in part.x..<part.maxX {
                    try tiles[i].setPixel(x: px - rect.x, y: py - rect.y, buffer.pixel(x: px - x, y: py - y))
                }
            }
        }
    }

    /// `rect` of the layer (layer pixels; outside it is clear) as one buffer.
    func flattened(_ rect: PixelRect) throws -> PixelBuffer {
        var part = try PixelBuffer(width: rect.width, height: rect.height)
        for i in tileIndices(in: rect) where tiles.indices.contains(i) {
            let at = tileRect(i)
            guard let shared = at.intersection(rect) else { continue }
            let tile = tiles[i]
            let piece = shared == at ? tile
                : try tile.cropped(x: shared.x - at.x, y: shared.y - at.y, width: shared.width, height: shared.height)
            try part.composite(piece, x: shared.x - rect.x, y: shared.y - rect.y, mode: .normal, opacity: 1)
        }
        return part
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
