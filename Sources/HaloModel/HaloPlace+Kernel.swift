// HaloPlace+Kernel.swift: Halo's project as the kernel's PlacedImageTarget (placed-images PH-1 stubs,
// PH-6 bodies): a solid keeps a PNG, JPEG or SVG picture in its own box; other kinds take none, so
// `placeFillBox` is nil there. Until PH-6 the mutating requirements throw not-built. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteKernel

extension HaloProject: PlacedImageTarget {
    /// Why nothing can be placed: no composition, or (until PH-6) not built.
    static let noPlaceComposition = "Make or open a composition to place into.",
        placeNotBuiltHelp = "Placing images in Halo isn't built yet.",
        cantReadImage = "Can't read this image."
    /// What the mutating requirements throw until PH-6 lands their bodies.
    static let placeNotBuilt = CatalogError.notBuilt(id: "place.image", feature: "halo placed-images PH-6")

    /// Why nothing can be placed now; nil once PH-6 lands the bodies.
    public var placeHelp: String? { selectedComposition == nil ? Self.noPlaceComposition : Self.placeNotBuiltHelp }

    /// What a new picture fits inside: the composition's frame, or an empty rect with none.
    public var placeCanvas: Rect {
        guard let comp = selectedComposition else { return Rect(minX: 0, minY: 0, maxX: 0, maxY: 0) }
        return Rect(minX: 0, minY: 0, maxX: Double(comp.width), maxY: Double(comp.height))
    }

    /// The selected solid's box, which a fill covers; nil for any other kind.
    public var placeFillBox: Rect? {
        guard let comp = selectedComposition, let layer = selectedLayer, layer.kind == .solid else { return nil }
        return layer.fillBox(in: comp)
    }

    /// PNG and JPEG raster, SVG through the kernel's PlacedVector.
    public var placeFormats: Set<PlacedFormat> { [.png, .jpeg, .svg] }

    /// The selected solid's picture in its box, with its focus; nil when it shows none.
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? {
        guard let box = placeFillBox, let layer = selectedLayer, let asset = layer.placedAsset else { return nil }
        return (layer.id, PlacedImage(assetID: asset.id, box: box, focus: layer.placedFocus), asset)
    }

    /// A PNG's or JPEG's pixel size from its header; the kernel sizes SVG itself.
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size {
        guard format != .svg else { throw CatalogError.unavailable(id: "place.image", why: PlaceRules.formatHelp) }
        let size = format == .png ? (try? PNG.info(data)).map { ($0.width, $0.height) } : (try? JPEG.info(data)).map { ($0.width, $0.height) }
        guard let size else { throw CatalogError.unavailable(id: "place.image", why: Self.cantReadImage) }
        return Size(width: Double(size.0), height: Double(size.1))
    }

    /// PH-6: adds a solid showing `asset` in `image.box` above the selection.
    public mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String {
        throw Self.placeNotBuilt
    }

    /// PH-6: sets the selected solid's picture, box and focus as one step.
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws {
        throw Self.placeNotBuilt
    }
}
