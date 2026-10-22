// HaloPlace+Kernel.swift: Halo's project as the kernel's PlacedImageTarget
// (placed-images PH-1 stubs, PH-6 bodies), so the `place.*` commands put a
// PNG, JPEG or SVG picture into a solid layer. A solid keeps its picture in
// `HaloLayer.placedAsset` and `placedFocus` and draws it into its own box
// (its rect, or the whole composition), so the selection's box is the
// solid's. Text, shape and null layers take no picture: `placeFillBox` is
// nil there and the kernel refuses a fill. Until PH-6 the two mutating
// requirements throw a not-built error and `placeHelp` says why. Linux-safe.
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

    /// Why nothing can be placed now: no composition, or the stub's not-built
    /// help, nil once PH-6 lands the bodies.
    public var placeHelp: String? {
        selectedComposition == nil ? Self.noPlaceComposition : Self.placeNotBuiltHelp
    }

    /// What a new picture fits inside: the composition's frame, or an empty
    /// rect with none.
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

    /// The selected solid's picture in its box, with its focus; nil when the
    /// selection shows none.
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? {
        guard let box = placeFillBox, let layer = selectedLayer, let asset = layer.placedAsset else { return nil }
        return (layer.id, PlacedImage(assetID: asset.id, box: box, focus: layer.placedFocus), asset)
    }

    /// A PNG's or JPEG's pixel size from its header; the kernel sizes SVG itself.
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size {
        let size: (width: Int, height: Int)
        switch format {
        case .png:
            guard let info = try? PNG.info(data) else { throw CatalogError.unavailable(id: "place.image", why: Self.cantReadImage) }
            size = (info.width, info.height)
        case .jpeg:
            guard let info = try? JPEG.info(data) else { throw CatalogError.unavailable(id: "place.image", why: Self.cantReadImage) }
            size = (info.width, info.height)
        case .svg:
            throw CatalogError.unavailable(id: "place.image", why: PlaceRules.formatHelp)
        }
        return Size(width: Double(size.width), height: Double(size.height))
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
