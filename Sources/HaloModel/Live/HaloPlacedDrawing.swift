// Live/HaloPlacedDrawing.swift: placed-images PH-1 stub, PH-5 body. A solid's picture as pixels: PNG or JPEG
// decoded once per asset (`decodes` counts them), SVG through PlacedVector, clipped to the outline. Linux-safe.
import CoreRaster
import SuiteKernel

struct HaloPlacedDrawing: Sendable {
    /// How many times an asset's bytes were decoded.
    private(set) var decodes = 0
    init() {}

    /// PH-5: `image` of `asset` through `matrix` on a `width` × `height` frame; nil draws the solid's color.
    mutating func source(_ asset: PlacedAsset, _ image: PlacedImage, matrix: HaloMatrix, width: Int, height: Int) throws -> PixelBuffer? { nil }
}
