// PhotoLayerComposite.swift: one layer's contribution to the picture under
// it, the per-layer step of the renderer and of LiveEdit's Merge Down and
// Flatten (photo-seams review note 2), so all three pick up adjustment layers
// and masks from one place. Today a pixel layer composites with its blend
// mode and opacity at its offset (CoreRaster's composite, tile by tile, each
// clipped to the region, exactly as the renderer always did); an adjustment
// layer (AL-2 of photo-adjustment-layers) turns `below` into
// `adjusting.applying` its settings with its opacity and blend mode, or gives
// `below` back when hidden or at opacity 0; the mask is ignored until PV-5
// fills it through `masking` (and passes it to `applying`). Callers still skip
// hidden and 0 % layers themselves. Linux-safe.
//
// Cost: CoreRaster's composite returns a fresh copy of its backdrop, so each
// layer tile goes onto one tile of the picture's own grid instead of onto the
// whole picture: a layer costs its pixels, not a picture copy per tile. The
// composite is per pixel and layer tiles don't overlap, so the result is the
// same bits. Picture tiles are independent, so they run across the cores.
// Merge Down and Flatten keep their picture as TiledPixels (same grid), so
// they never copy a whole picture at all. A picture of one tile (each region
// the renderer draws) is its own only tile, so it skips the read and the
// write back: one copy per layer, not three, on every brush event. Two
// composites give their answer without running (#1636, PB-13): an opaque
// normal layer tile at opacity 1 covering a picture tile is that tile, and a
// layer tile composites only over the rectangle it paints, since a clear
// pixel leaves its backdrop alone. CoreRaster's composite is about 37 ns a
// pixel, so a 256 px tile under an opaque Background and a partly painted
// layer drops from about 5 ms to about 3. An adjustment layer is per pixel,
// so it costs the region it covers: the whole region at once, or tile by
// tile across the cores on a tiled picture.
import CoreRaster
import Dispatch
import Synchronization

public enum PhotoLayerComposite {
    /// `content` composited onto `below`, a region of the canvas whose
    /// top-left pixel is canvas pixel `origin`. Only the layer's tiles under
    /// the region are visited. Throws `RasterError` when CoreRaster rejects
    /// the layer's opacity.
    public static func composite(_ content: LayerContent, onto below: PixelBuffer,
                                 origin: (x: Int, y: Int),
                                 adjusting: any AdjustmentLayering,
                                 masking: any LayerMasking) throws -> PixelBuffer {
        if case .adjustment(let settings) = content.layer.kind {
            let layer = content.layer
            guard layer.isVisible && layer.opacity > 0 else { return below }
            return try adjusting.applying(settings, to: below, opacity: layer.opacity,
                                          blendMode: layer.blendMode, mask: nil)
        }
        let columns = below.tileColumns
        if columns == 1 && below.tileRows == 1 {
            let pieces = try pictureTiles(content, width: below.width, height: below.height, columns: 1,
                                          origin: origin) { _ in below }
            return pieces.first?.1 ?? below
        }
        let pieces = try pictureTiles(content, width: below.width, height: below.height, columns: columns,
                                      origin: origin) { try below.tile(column: $0 % columns, row: $0 / columns) }
        guard !pieces.isEmpty else { return below }
        var picture = below
        for (index, piece) in pieces {
            try picture.replaceTile(column: index % columns, row: index / columns, with: piece)
        }
        return picture
    }

    /// `composite` onto a tiled picture: the same tiles, the same bits.
    static func composite(_ content: LayerContent, onto below: TiledPixels,
                          origin: (x: Int, y: Int),
                          adjusting: any AdjustmentLayering,
                          masking: any LayerMasking) throws -> TiledPixels {
        if case .adjustment(let settings) = content.layer.kind {
            let layer = content.layer, tiles = below.tiles
            guard layer.isVisible && layer.opacity > 0 else { return below }
            var picture = below
            picture.tiles = try inParallel(tiles.count) {
                try adjusting.applying(settings, to: tiles[$0], opacity: layer.opacity,
                                       blendMode: layer.blendMode, mask: nil)
            }
            return picture
        }
        let pieces = try pictureTiles(content, width: below.width, height: below.height, columns: below.columns,
                                      origin: origin) { index in
            guard below.tiles.indices.contains(index) else { throw RasterError.invalid("tile \(index) is missing") }
            return below.tiles[index]
        }
        var picture = below
        for (index, piece) in pieces where picture.tiles.indices.contains(index) { picture.tiles[index] = piece }
        return picture
    }

    /// The picture tiles `content` lands on (row-major index on a grid of
    /// `columns`), each read through `read` and composited with every layer
    /// tile over it; empty for a layer with no pixels.
    private static func pictureTiles(
        _ content: LayerContent, width: Int, height: Int, columns: Int, origin: (x: Int, y: Int),
        read: @Sendable (Int) throws -> PixelBuffer
    ) throws -> [(Int, PixelBuffer)] {
        let layer = content.layer
        // ponytail: PV-5 masks with masking.masked. An adjustment layer never gets here.
        guard case .pixels = layer.kind, let tiled = content.pixels else { return [] }
        let region = PixelRect(x: origin.x - layer.offsetX, y: origin.y - layer.offsetY, width: width, height: height)
        // Each layer tile under the region, in picture pixels, filed under
        // every picture tile it overlaps.
        let size = PixelBuffer.tileSize
        var hits: [Int: [(tile: Int, at: PixelRect)]] = [:]
        for i in tiled.tileIndices(in: region) where tiled.tiles.indices.contains(i) {
            let at = tiled.tileRect(i).offsetBy(layer.offsetX - origin.x, layer.offsetY - origin.y)
            guard let area = at.intersection(PixelRect(x: 0, y: 0, width: width, height: height)) else { continue }
            for row in (area.y / size)...((area.maxY - 1) / size) {
                for column in (area.x / size)...((area.maxX - 1) / size) {
                    hits[row * columns + column, default: []].append((i, at))
                }
            }
        }
        let jobs = hits.sorted { $0.key < $1.key }
        let mode = layer.blendMode, opacity = Float(layer.opacity)
        let pieces = try inParallel(jobs.count) { job in
            let (index, placed) = jobs[job]
            let x = index % columns * size, y = index / columns * size
            var piece = try read(index)
            for hit in placed {
                let tile = tiled.tiles[hit.tile], dx = hit.at.x - x, dy = hit.at.y - y
                guard (0...1).contains(opacity) else {
                    // CoreRaster throws for this opacity.
                    piece = try CoreRaster.composite(tile, onto: piece, x: dx, y: dy, mode: mode, opacity: opacity)
                    continue
                }
                if try replaces(tile, piece, dx: dx, dy: dy, mode: mode, opacity: opacity) {
                    piece = tile
                    continue
                }
                guard let painted = try paintedRect(of: tile) else { continue }
                let source = painted.width == tile.width && painted.height == tile.height ? tile
                    : try tile.cropped(x: painted.x, y: painted.y, width: painted.width, height: painted.height)
                piece = try CoreRaster.composite(
                    source, onto: piece, x: dx + painted.x, y: dy + painted.y, mode: mode, opacity: opacity)
            }
            return piece
        }
        return Array(zip(jobs.map(\.key), pieces))
    }

    /// Whether `tile` at (dx, dy) composited onto `piece` gives `tile` itself:
    /// normal at opacity 1, covering the whole piece, every pixel opaque.
    /// Source-over then keeps none of the backdrop (1 - alpha is 0) and the
    /// straight color times alpha 1 is the color, so the same bits; skipping
    /// the composite saves a per-pixel pass, such as an opaque Background
    /// under every rendered tile. The scan stops at the first pixel that isn't
    /// opaque, so a layer with any transparency costs about one pixel read.
    static func replaces(_ tile: PixelBuffer, _ piece: PixelBuffer, dx: Int, dy: Int,
                         mode: BlendMode, opacity: Float) throws -> Bool {
        guard mode == .normal, opacity == 1, dx == 0, dy == 0,
            tile.width == piece.width, tile.height == piece.height
        else { return false }
        for y in 0..<tile.height {
            for x in 0..<tile.width {
                if try tile.pixel(x: x, y: y).a != 1 { return false }
            }
        }
        return true
    }

    /// The smallest rectangle of `tile` holding every pixel with alpha above
    /// 0; nil when the whole tile is clear. A clear source pixel leaves its
    /// backdrop pixel as it was in every blend mode (its straight color is
    /// clear, its weight 0 and the backdrop's 1), so only this rectangle needs
    /// compositing: a layer that paints part of a tile costs that part. Rows
    /// are read from each end until one is painted, then each painted row
    /// from both ends, so a tile painted to its edges costs a few reads.
    static func paintedRect(of tile: PixelBuffer) throws -> PixelRect? {
        func clear(_ x: Int, _ y: Int) throws -> Bool { try tile.pixel(x: x, y: y).a == 0 }
        func clearRow(_ y: Int) throws -> Bool {
            for x in 0..<tile.width where try !clear(x, y) { return false }
            return true
        }
        var top = 0
        while top < tile.height, try clearRow(top) { top += 1 }
        guard top < tile.height else { return nil }
        var bottom = tile.height - 1
        while bottom > top, try clearRow(bottom) { bottom -= 1 }
        var left = tile.width, right = -1
        for y in top...bottom {
            var x = 0
            while x < left, try clear(x, y) { x += 1 }
            left = min(left, x)
            var end = tile.width - 1
            while end > right, try clear(end, y) { end -= 1 }
            right = max(right, end)
        }
        guard right >= left else { return nil }
        return PixelRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
    }

    /// `work(0) ... work(count - 1)` run across the cores, in index order.
    /// Rethrows the error of the lowest index that threw.
    static func inParallel<T: Sendable>(_ count: Int, _ work: @Sendable (Int) throws -> T) throws -> [T] {
        let results = Mutex<[Int: Result<T, any Error>]>([:])
        DispatchQueue.concurrentPerform(iterations: count) { i in
            let result = Result { try work(i) }
            results.withLock { $0[i] = result }
        }
        return try results.withLock { done in try (0..<count).compactMap { try done[$0]?.get() } }
    }
}
