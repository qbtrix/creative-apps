// HealRules.swift (fill-heal FH-1 stubs, FH-5h bodies): spot heal, heal and
// remove over creative-core. Spot heal fills a disc from the texture around
// it (`filledFromSurroundings`, whose patch search and seam heal are core's),
// heal clones from a source offset and solves the seam (`healed`), and remove
// fills a stroke or a selection, grown a little, from its surroundings. Every
// mask is buffer-sized, as core takes it. Linux-safe.
import CoreRaster
import SuiteKernel

/// The heal tools' pixel rules.
public enum HealRules {
    /// How far remove grows its mask: core's feather radius, whose fade reaches about 2 px past the edge.
    static let growRadius = 4.0

    /// `pixels` with the disc `size` wide (clamped to 1...500) centred on
    /// pixel `p` rebuilt from the texture around it; `seed` picks between
    /// equal candidates, so a script repeats.
    public static func spotHeal(_ pixels: PixelBuffer, at p: (x: Int, y: Int), size: Double, seed: UInt64) throws -> PixelBuffer {
        let radius = (size.isNaN ? 1 : min(500, max(1, size))) / 2
        let disc = try Mask.ellipse(width: pixels.width, height: pixels.height, centerX: Double(p.x) + 0.5,
                                    centerY: Double(p.y) + 0.5, radiusX: radius, radiusY: radius)
        return try pixels.filledFromSurroundings(disc, seed: seed)
    }

    /// `pixels` with the texture `sourceOffset` away cloned through
    /// `coverage` and its tone solved to meet the edge: pixel (x, y) takes
    /// its texture from (x + dx, y + dy). Throws when a source pixel lies off
    /// the buffer or the mask's size differs from the pixels'.
    public static func heal(_ pixels: PixelBuffer, through coverage: Mask, sourceOffset: (dx: Int, dy: Int)) throws -> PixelBuffer {
        try pixels.healed(offset: (dx: sourceOffset.dx, dy: sourceOffset.dy), through: coverage)
    }

    /// `pixels` with what `coverage` covers, grown by about 2 px so no edge
    /// pixel of the object stays, rebuilt from its surroundings. The same
    /// seed gives the same pixels; an empty coverage changes nothing.
    public static func remove(_ pixels: PixelBuffer, through coverage: Mask, seed: UInt64) throws -> PixelBuffer {
        guard coverage.coveredBounds != nil else { return pixels }
        var grown = coverage
        try grown.add(coverage.feathered(radius: growRadius))
        return try pixels.filledFromSurroundings(grown, seed: seed)
    }

    /// A `width` x `height` mask holding `grid`'s coverage at its origin;
    /// the part of the grid off the buffer is dropped.
    public static func mask(_ grid: CoverageGrid, width: Int, height: Int) throws -> Mask {
        var alpha = try PixelBuffer(width: width, height: height)
        let rows = max(0, -grid.originY)..<max(0, min(grid.height, height - grid.originY))
        let cols = max(0, -grid.originX)..<max(0, min(grid.width, width - grid.originX))
        for row in rows {
            for col in cols {
                let i = row * grid.width + col
                guard i < grid.values.count, grid.values[i] > 0 else { continue }
                try alpha.setPixel(x: grid.originX + col, y: grid.originY + row, RGBA(r: 0, g: 0, b: 0, a: min(1, grid.values[i])))
            }
        }
        return try Mask(from: alpha, .alpha)
    }
}
