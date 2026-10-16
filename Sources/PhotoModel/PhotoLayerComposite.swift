// PhotoLayerComposite.swift: one layer's contribution to the picture under
// it, the per-layer step of the renderer and of LiveEdit's Merge Down and
// Flatten (photo-seams review note 2), so all three pick up adjustment layers
// and masks from one place. Today a pixel layer composites with its blend
// mode and opacity at its offset (CoreRaster's composite, tile by tile, each
// clipped to the region, exactly as the renderer always did); an adjustment
// layer gives back `below` unchanged until photo-adjustment-layers fills that
// case through `adjusting`; the mask is ignored until PV-5 fills it through
// `masking`. Whether a layer shows at all (hidden, opacity 0) is the caller's
// call. Linux-safe.
//
// Cost: CoreRaster's composite returns a fresh copy of its backdrop, so each
// layer tile goes onto one tile of the picture's own grid instead of onto the
// whole picture: a layer costs its pixels, not a picture copy per tile. The
// composite is per pixel and layer tiles don't overlap, so the result is the
// same bits. Picture tiles are independent, so they run across the cores.
// Merge Down and Flatten keep their picture as TiledPixels (same grid), so
// they never copy a whole picture at all. A picture of one tile (each region
// the renderer draws) is its own only tile, so it skips the read and the
// write back: one copy per layer, not three, on every brush event.
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
        // ponytail: photo-adjustment-layers fills .adjustment with adjusting.applying, PV-5 masks with masking.masked.
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
                piece = try CoreRaster.composite(
                    tiled.tiles[hit.tile], onto: piece, x: hit.at.x - x, y: hit.at.y - y, mode: mode, opacity: opacity)
            }
            return piece
        }
        return Array(zip(jobs.map(\.key), pieces))
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
