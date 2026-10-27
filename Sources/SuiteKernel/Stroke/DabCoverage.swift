// DabCoverage.swift (fill-heal FH-1 stub, FH-5k body): how much of each pixel
// a brush stroke covers. The dabs `DabSpacer` lays along the points, each a
// disc of the brush's size and hardness, max-combined into one grid over the
// stroke's bounds. The heal and remove tools turn the grid into their mask.
// Foundation only: no raster types, so the kernel stays small. Nothing traps:
// a NaN, an infinite or a far-off value gives an empty grid.
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
    /// The most dabs one stroke lays, and the most pixels its grid holds.
    static let maxDabs = 100_000, maxCells = 1 << 26
    /// How far from the origin a dab may sit, in pixels.
    static let reach = 1_000_000.0

    /// The stroke through `points` with `brush`'s size, hardness and spacing:
    /// each dab a disc, overlapping dabs keeping the larger coverage. Empty
    /// for no points, a NaN size or a grid past `maxCells`.
    public static func stroke(_ points: [Point], brush: BrushSettings) -> CoverageGrid {
        guard let last = points.last, !brush.size.isNaN else { return .empty }
        let size = min(500, max(1, brush.size))
        let spacing = brush.spacing.isNaN ? 25 : min(1000, max(1, brush.spacing))
        var centres: [Point] = []
        for (a, b) in zip(points, points.dropFirst()) where centres.count < maxDabs {
            centres += DabSpacer.centers(a, b, spacing: size * spacing / 100, cap: maxDabs - centres.count)
        }
        centres.append(last)
        let dabs = centres.map { disc(at: $0, size: size, hardness: brush.hardness / 100) }.filter { !$0.values.isEmpty }
        guard let first = dabs.first else { return .empty }
        var (x0, y0, x1, y1) = (first.originX, first.originY, first.originX + first.width, first.originY + first.height)
        for d in dabs {
            (x0, y0) = (min(x0, d.originX), min(y0, d.originY))
            (x1, y1) = (max(x1, d.originX + d.width), max(y1, d.originY + d.height))
        }
        let (w, h) = (x1 - x0, y1 - y0)
        guard w > 0, h > 0, w <= maxCells / h else { return .empty }
        var values = [Float](repeating: 0, count: w * h)
        for d in dabs {
            for row in 0..<d.height {
                for col in 0..<d.width {
                    let (k, i) = (row * d.width + col, (d.originY - y0 + row) * w + (d.originX - x0 + col))
                    guard k < d.values.count, values.indices.contains(i) else { continue }
                    values[i] = max(values[i], d.values[k])
                }
            }
        }
        return CoverageGrid(originX: x0, originY: y0, width: w, height: h, values: values)
    }

    /// One dab: a disc `size` wide (clamped to 1...500) at `p`, full
    /// coverage out to `hardness` (0...1, NaN read as 1) of its radius,
    /// falling linearly to 0 at the edge. A pixel's coverage is read at its
    /// centre. Empty for a NaN size or a point that is not finite or is
    /// farther than `reach` from the origin.
    public static func disc(at p: Point, size: Double, hardness: Double) -> CoverageGrid {
        guard !size.isNaN, abs(p.x) < reach, abs(p.y) < reach else { return .empty }
        let r = min(500, max(1, size)) / 2
        let full = r * (hardness.isNaN ? 1 : min(1, max(0, hardness)))
        let (x0, y0) = (Int((p.x - r).rounded(.down)), Int((p.y - r).rounded(.down)))
        let (w, h) = (Int((p.x + r).rounded(.up)) - x0, Int((p.y + r).rounded(.up)) - y0)
        var values: [Float] = []
        values.reserveCapacity(w * h)
        for y in 0..<h {
            for x in 0..<w {
                let (dx, dy) = (Double(x0 + x) + 0.5 - p.x, Double(y0 + y) + 0.5 - p.y)
                let d = (dx * dx + dy * dy).squareRoot()
                values.append(d <= full ? 1 : d >= r ? 0 : Float((r - d) / (r - full)))
            }
        }
        return CoverageGrid(originX: x0, originY: y0, width: w, height: h, values: values)
    }
}
