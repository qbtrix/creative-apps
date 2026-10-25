// FilterRules.swift (adjust-everywhere AJ-1 stubs, AJ-5f bodies): the five
// filters over creative-core. `apply` runs core's op on the layer padded by the
// op's reach (3 sigma for a blur, the distance for motion), then mixes result
// and input by the selection's coverage, so a pixel with coverage 0 is copied,
// never recomputed. Add Noise hashes (x, y, seed), so a script repeats exactly.
// `preview` runs the same filter on a copy whose longest side is at most
// `longestSide`. Linux-safe.
import CoreRaster
import SuiteKernel

/// The filters' pixel rules.
public enum FilterRules {
    /// What every rule throws until AJ-5f.
    public static let notBuilt = CatalogError.notBuilt(id: "filter", feature: "adjust-everywhere AJ-5f")
    /// The longest side of the copy a sheet's Preview filters.
    public static let previewSide = 1024

    /// One pass of `f` over `pixels`, only where `coverage` is above 0 and mixed by it; nil coverage is
    /// everywhere. Throws for a coverage of another size.
    public static func apply(_ f: ImagingFilter, to pixels: PixelBuffer, coverage: Mask?) throws -> PixelBuffer {
        throw notBuilt
    }

    /// `apply` on a copy of `pixels` and `coverage` scaled so the longest side is at most `longestSide`.
    public static func preview(_ f: ImagingFilter, to pixels: PixelBuffer, coverage: Mask?,
                               longestSide: Int = previewSide) throws -> PixelBuffer {
        throw notBuilt
    }
}
