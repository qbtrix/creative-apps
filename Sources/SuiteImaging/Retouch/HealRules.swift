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
    /// What a run throws until FH-5h.
    public static let notBuilt = CatalogError.notBuilt(id: "retouch", feature: "fill-heal FH-5h")

    /// `pixels` with the disc `size` wide at `p` rebuilt from the texture
    /// around it; `seed` picks between equal candidates, so a script repeats.
    public static func spotHeal(_ pixels: PixelBuffer, at p: (x: Int, y: Int), size: Double, seed: UInt64) throws -> PixelBuffer {
        throw notBuilt
    }

    /// `pixels` with the texture `sourceOffset` away cloned through
    /// `coverage` and its tone solved to meet the edge. Throws when a source
    /// pixel lies off the buffer.
    public static func heal(_ pixels: PixelBuffer, through coverage: Mask, sourceOffset: (dx: Int, dy: Int)) throws -> PixelBuffer {
        throw notBuilt
    }

    /// `pixels` with what `coverage` covers, grown by a couple of pixels,
    /// rebuilt from its surroundings. The same seed gives the same pixels.
    public static func remove(_ pixels: PixelBuffer, through coverage: Mask, seed: UInt64) throws -> PixelBuffer {
        throw notBuilt
    }

    /// A `width` x `height` mask holding `grid`'s coverage at its origin;
    /// the part of the grid off the buffer is dropped.
    public static func mask(_ grid: CoverageGrid, width: Int, height: Int) throws -> Mask {
        throw notBuilt
    }
}
