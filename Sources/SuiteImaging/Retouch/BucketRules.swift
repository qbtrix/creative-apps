// BucketRules.swift (fill-heal FH-1 stubs, FH-5b bodies): the paint bucket.
// The region is creative-core's flood mask from the seed in the sampled
// picture (the target layer, or the merged picture with All Layers), times
// the selection's coverage when there is one; the fill mixes the colour into
// the target by that region. Linux-safe.
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
    /// What a run throws until FH-5b.
    public static let notBuilt = CatalogError.notBuilt(id: "fill.bucket", feature: "fill-heal FH-5b")

    /// The region to fill: the seed's flood mask in `sample`, times the
    /// selection's coverage when there is one. Buffer-sized. Throws for a
    /// seed off the buffer or a selection of another size.
    public static func region(seed: (x: Int, y: Int), in sample: PixelBuffer, options: BucketOptions,
                              selection: Mask?) throws -> Mask {
        throw notBuilt
    }

    /// `pixels` with `color` (straight, not premultiplied) mixed in by
    /// `region`'s coverage; pixels the region misses are unchanged.
    public static func fill(_ pixels: PixelBuffer, region: Mask, color: RGBA) throws -> PixelBuffer {
        throw notBuilt
    }
}
