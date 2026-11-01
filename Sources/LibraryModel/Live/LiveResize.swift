// Live/LiveResize.swift: CoreRaster's `resized` across the cores, giving the same
// pixels, for the export's shrink of a full-size photo (quality gate #5953).
// `resized` makes two 1-D passes, the one that leaves the smaller intermediate
// first. In the vertical pass each output column reads only its own input
// column, and in the horizontal pass each output row reads only its own row.
// So each pass runs on 256 px strips of the buffer (columns for the vertical
// pass, rows for the horizontal), each strip through core's own `resized` with
// one side unchanged. That runs just that pass, with the same taps and the same
// sums. The strips go back tile by tile. The pass order is core's rule.
import CoreRaster

enum LiveResize {
    /// `b` resized to `width` x `height` with `filter`, equal to `b.resized(width:height:filter:)`.
    static func resized(_ b: PixelBuffer, width: Int, height: Int,
                        filter: ResampleFilter = .lanczos3) throws -> PixelBuffer {
        if width * b.height <= b.width * height {
            return try vertical(horizontal(b, width: width, filter: filter), height: height, filter: filter)
        }
        return try horizontal(vertical(b, height: height, filter: filter), width: width, filter: filter)
    }

    /// `b` resized to `width` wide, one band of tile rows per piece.
    private static func horizontal(_ b: PixelBuffer, width: Int, filter: ResampleFilter) throws -> PixelBuffer {
        guard width != b.width else { return b }
        let size = PixelBuffer.tileSize
        let bands = try LiveParallel.run(b.tileRows) { r in
            let band = try b.cropped(x: 0, y: r * size, width: b.width, height: min(size, b.height - r * size))
            return try band.resized(width: width, height: band.height, filter: filter)
        }
        var out = try PixelBuffer(width: width, height: b.height)
        for (r, band) in bands.enumerated() {
            for c in 0..<band.tileColumns { try out.replaceTile(column: c, row: r, with: band.tile(column: c, row: 0)) }
        }
        return out
    }

    /// `b` resized to `height` high, one strip of tile columns per piece.
    private static func vertical(_ b: PixelBuffer, height: Int, filter: ResampleFilter) throws -> PixelBuffer {
        guard height != b.height else { return b }
        let size = PixelBuffer.tileSize
        let strips = try LiveParallel.run(b.tileColumns) { c in
            let strip = try b.cropped(x: c * size, y: 0, width: min(size, b.width - c * size), height: b.height)
            return try strip.resized(width: strip.width, height: height, filter: filter)
        }
        var out = try PixelBuffer(width: b.width, height: height)
        for (c, strip) in strips.enumerated() {
            for r in 0..<strip.tileRows { try out.replaceTile(column: c, row: r, with: strip.tile(column: 0, row: r)) }
        }
        return out
    }
}
