// BucketRules.swift (fill-heal FH-1 stubs, FH-5b bodies): the paint bucket.
// The region is creative-core's flood mask from the seed in the sampled
// picture (the target layer, or the merged picture with All Layers), times
// the selection's coverage when there is one; the fill mixes the colour into
// the target by that region. Core's anti-alias gives the one-pixel soft edge.
// Linux-safe.
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
    /// reads as core's OKLab distance t / 255. Throws for a seed off the
    /// buffer or a selection of another size.
    public static func region(seed: (x: Int, y: Int), in sample: PixelBuffer, options: BucketOptions,
                              selection: Mask?) throws -> Mask {
        let tolerance = Float(min(255, max(0, options.tolerance))) / 255
        var m = try sample.floodMask(from: seed, tolerance: .within(tolerance), contiguous: options.contiguous,
                                     antiAlias: options.antiAlias)
        if let selection { try m.intersect(selection) }
        return m
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
