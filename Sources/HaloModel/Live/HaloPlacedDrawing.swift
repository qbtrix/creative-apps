// Live/HaloPlacedDrawing.swift: placed-images PH-1 stub, PH-5 body. Turns a
// solid's picture into pixels the frame renderer composites: a PNG or JPEG
// decoded once per asset id, an SVG filled through the kernel's
// PlacedVector, drawn through the layer's matrix and clipped to the solid's
// outline. `decodes` counts the decodes, so a test can see the cache work.
// Until PH-5 `source` returns nil and the solid draws its color. Linux-safe.
import CoreRaster
import SuiteKernel

struct HaloPlacedDrawing: Sendable {
    /// How many times an asset's bytes were decoded.
    private(set) var decodes = 0

    init() {}

    /// PH-5: `image` of `asset` through `matrix` on a `width` × `height`
    /// frame, transparent outside the picture; nil draws the solid's color.
    mutating func source(
        _ asset: PlacedAsset, _ image: PlacedImage, matrix: HaloMatrix, width: Int, height: Int
    ) throws -> PixelBuffer? {
        nil
    }
}
