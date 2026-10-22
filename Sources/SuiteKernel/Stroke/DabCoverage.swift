// DabCoverage.swift (fill-heal FH-1 stub, FH-5k body): how much of each pixel
// a brush stroke covers. The dabs `DabSpacer` lays along the points, each a
// disc of the brush's size and hardness, max-combined into one grid over the
// stroke's bounds. The heal and remove tools turn the grid into their mask.
// Foundation only: no raster types, so the kernel stays small.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Coverage 0...1 per pixel over a rectangle of document pixels, row by row.
public struct CoverageGrid: Hashable, Sendable {
    /// The top-left pixel in document space and the size in pixels.
    public var originX, originY, width, height: Int
    /// `width * height` values, 0...1, row by row from the top.
    public var values: [Float]

    /// A grid at (originX, originY) holding `values`, row by row.
    public init(originX: Int, originY: Int, width: Int, height: Int, values: [Float]) {
        (self.originX, self.originY, self.width, self.height, self.values) = (originX, originY, width, height, values)
    }

    /// No pixels: what nothing to stroke gives.
    public static let empty = CoverageGrid(originX: 0, originY: 0, width: 0, height: 0, values: [])
}

/// The coverage of a stroke's dabs and of one dab.
public enum DabCoverage {
    /// The stroke through `points` with `brush`'s size, hardness and spacing:
    /// each dab a disc, overlapping dabs keeping the larger coverage. Empty
    /// for no points. FH-1: always empty; FH-5k fills it.
    public static func stroke(_ points: [Point], brush: BrushSettings) -> CoverageGrid {
        .empty
    }

    /// One dab: a disc `size` wide at `p`, full coverage out to `hardness`
    /// (0...1) of its radius, falling to 0 at the edge. FH-1: always empty.
    public static func disc(at p: Point, size: Double, hardness: Double) -> CoverageGrid {
        .empty
    }
}
