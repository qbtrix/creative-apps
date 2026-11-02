// Live/HaloPlacedDrawing.swift: placed-images PH-5, a solid's picture as pixels on the frame. A PNG or JPEG is
// decoded once per asset id (`decodes` counts real decodes, however many layers show it) and drawn through
// the layer's matrix with CoreRaster's affine composite into PlaceRules.drawnRect, the cover crop of its box.
// An SVG goes through PlaceRules.vector, each item filled by SuiteImaging's PlacedVectorPixels.
// LiveFrameRendering clips the result to the solid's outline. `shared` is the process-wide cache, behind a Mutex so it stays Sendable under Swift 6; it empties itself past `budget` pixels. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import FlareCore
import SuiteImaging
import SuiteKernel
import Synchronization

struct HaloPlacedDrawing: Sendable {
    /// The cache every render shares, so a picture is decoded once per asset across frames.
    static let shared = Mutex(HaloPlacedDrawing())
    /// The decoded pixels the cache keeps before it starts over.
    static let budget = 32_000_000

    /// How many times an asset's bytes were decoded.
    private(set) var decodes = 0
    private var rasters: [String: PixelBuffer] = [:]
    private var vectors: [String: PlacedVector] = [:]
    init() {}

    /// `image` of `asset` through `matrix`, then the frame's `scaleX` × `scaleY`, on a clear `width` × `height`
    /// buffer, premultiplied linear; nil for an empty picture. Throws when the bytes don't decode.
    mutating func source(
        _ asset: PlacedAsset, _ image: PlacedImage, matrix: HaloMatrix, width: Int, height: Int,
        scaleX: Double = 1, scaleY: Double = 1
    ) throws -> PixelBuffer? {
        let drawn = PlaceRules.drawnRect(image, natural: asset.natural)
        let world = HaloMatrix(a: scaleX, b: 0, c: 0, d: scaleY, tx: 0, ty: 0) * matrix
        var out = try PixelBuffer(width: width, height: height)
        let key = asset.id
        if asset.format == .svg {
            let vector = try vectors[key] ?? decodedVector(asset, key: key)
            guard vector.size.width > 0, vector.size.height > 0 else { return nil }
            let place = world * Self.placing(drawn, width: vector.size.width, height: vector.size.height)
            for item in vector.items { try Self.fill(item, through: place, onto: &out) }
        } else {
            let pixels = try rasters[key] ?? decodedRaster(asset, key: key)
            guard pixels.width > 0, pixels.height > 0 else { return nil }
            let m = world * Self.placing(drawn, width: Double(pixels.width), height: Double(pixels.height))
            let affine = AffineMatrix(a: m.a, b: m.b, c: m.c, d: m.d, tx: m.tx, ty: m.ty)
            try out.composite(pixels, through: affine, mode: .normal, opacity: 1, filter: .bilinear)
        }
        return out
    }

    /// The map from a `width` × `height` picture's own units onto `drawn`; both sizes are above zero.
    static func placing(_ drawn: Rect, width: Double, height: Double) -> HaloMatrix {
        HaloMatrix(a: drawn.width / width, b: 0, c: 0, d: drawn.height / height, tx: drawn.minX, ty: drawn.minY)
    }

    private mutating func decodedRaster(_ asset: PlacedAsset, key: String) throws -> PixelBuffer {
        let pixels = asset.format == .jpeg ? try JPEG.read(asset.data) : try PNG.read(asset.data)
        decodes += 1
        if rasters.values.reduce(pixels.width * pixels.height, { $0 + $1.width * $1.height }) > Self.budget {
            rasters.removeAll()
        }
        rasters[key] = pixels
        return pixels
    }

    private mutating func decodedVector(_ asset: PlacedAsset, key: String) throws -> PlacedVector {
        let vector = try PlaceRules.vector(asset.data, name: asset.name)
        decodes += 1
        vectors[key] = vector
        return vector
    }

    /// `item`'s fill over its contours mapped through `m`: SuiteImaging's shared vector fill.
    static func fill(_ item: PlacedVector.Item, through m: HaloMatrix, onto out: inout PixelBuffer) throws {
        try PlacedVectorPixels.fill(item, map: { m.apply($0) }, onto: &out)
    }
}

extension HaloLayer {
    /// This solid's picture in its box with its focus, as `placedSelection` maps it; nil when it shows none.
    func placedImage(in c: HaloComposition) -> PlacedImage? {
        guard kind == .solid, let asset = placedAsset else { return nil }
        return PlacedImage(assetID: asset.id, box: fillBox(in: c), focus: placedFocus)
    }
}
