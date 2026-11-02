// BucketRules.swift (fill-heal FH-1 stubs, FH-5b bodies): the paint bucket.
// The region is creative-core's flood mask from the seed in the sampled
// picture (the target layer, or the merged picture with All Layers), times
// the selection's coverage when there is one; the fill mixes the colour into
// the target by that region. Anti-alias softens the region's own one-pixel
// edge: each taken pixel there is covered by its closeness to the seed colour,
// so a pixel past the tolerance is never tinted (#5093). Linux-safe.
import CoreRaster
import SuiteKernel

/// The bucket's options bar: Tolerance, Contiguous, All Layers, Anti-alias.
public struct BucketOptions: Hashable, Codable, Sendable {
    /// How far a colour may sit from the seed's and still fill, 0...255.
    public var tolerance: Int
    /// True fills only pixels connected to the seed; false every match.
    public var contiguous: Bool
    /// True samples the merged picture; the fill still writes only the target layer.
    public var sampleAllLayers: Bool
    /// True gives the region a one-pixel soft edge.
    public var antiAlias: Bool

    /// Options with `tolerance` clamped to 0...255.
    public init(tolerance: Int = 32, contiguous: Bool = true, sampleAllLayers: Bool = false, antiAlias: Bool = true) {
        self.tolerance = min(255, max(0, tolerance))
        (self.contiguous, self.sampleAllLayers, self.antiAlias) = (contiguous, sampleAllLayers, antiAlias)
    }
}

/// The bucket's region and fill.
public enum BucketRules {
    /// The region to fill: the seed's flood mask in `sample`, times the
    /// selection's coverage when there is one. Buffer-sized. Tolerance t
    /// reads as core's OKLab distance t / 255; no pixel past it is covered.
    /// Throws for a seed off the buffer or a selection of another size.
    public static func region(seed: (x: Int, y: Int), in sample: PixelBuffer, options: BucketOptions,
                              selection: Mask?) throws -> Mask {
        let tolerance = Float(min(255, max(0, options.tolerance))) / 255
        // Core's own anti-alias covers rejected pixels up to twice the tolerance, which tints them.
        var m = try sample.floodMask(from: seed, tolerance: .within(tolerance), contiguous: options.contiguous,
                                     antiAlias: false)
        if options.antiAlias, tolerance > 0 { m = try softEdge(m, in: sample, seed: seed, tolerance: tolerance) }
        if let selection { try m.intersect(selection) }
        return m
    }

    /// `taken` with each pixel on its one-pixel edge (taken, with an
    /// untaken edge neighbour) covered by its own closeness to the seed
    /// colour, `1 - smoothstep(0, tolerance, d)`; the rest stays as it is.
    static func softEdge(_ taken: Mask, in sample: PixelBuffer, seed: (x: Int, y: Int), tolerance: Float) throws -> Mask {
        guard let box = taken.coveredBounds else { return taken }
        var edge = try PixelBuffer(width: taken.width, height: taken.height)
        for y in box.y..<(box.y + box.height) {
            for x in box.x..<(box.x + box.width) where try taken.coverage(x: x, y: y) > 0 {
                let neighbours = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)].filter {
                    (0..<taken.width).contains($0.0) && (0..<taken.height).contains($0.1)
                }
                guard try neighbours.contains(where: { try taken.coverage(x: $0.0, y: $0.1) == 0 }) else { continue }
                try edge.setPixel(x: x, y: y, RGBA(r: 0, g: 0, b: 0, a: 1))
            }
        }
        var shortfall = try sample.colorRangeMask(around: sample.pixel(x: seed.x, y: seed.y), fuzziness: tolerance)
        shortfall.invert()
        try shortfall.intersect(Mask(from: edge, .alpha))
        var out = taken
        try out.subtract(shortfall)
        return out
    }

    /// `pixels` with `color` (straight, not premultiplied) mixed in by
    /// `region`'s coverage; pixels the region misses are unchanged. Throws
    /// when the region's size differs from the pixels'.
    public static func fill(_ pixels: PixelBuffer, region: Mask, color: RGBA) throws -> PixelBuffer {
        guard region.width == pixels.width, region.height == pixels.height else {
            throw RasterError.invalid("bucket region \(region.width)x\(region.height) differs from layer \(pixels.width)x\(pixels.height)")
        }
        guard let box = region.coveredBounds else { return pixels }
        let solid = try PixelBuffer(width: box.width, height: box.height, fill: color.premultiplied())
        var out = pixels
        try out.composite(solid, x: box.x, y: box.y, mode: .normal, opacity: 1, mask: region, maskX: 0, maskY: 0)
        return out
    }
}
