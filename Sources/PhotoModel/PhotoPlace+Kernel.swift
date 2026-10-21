// PhotoPlace+Kernel.swift (place-image PP-1 stubs, PP-5 bodies): Photo's workspace is a kernel
// `PlacedImageTarget`, so the place commands in `PlaceCommands` put a PNG or JPEG into an open image the
// way the other apps place theirs. A placed image becomes pixels in Photo: `insertPlaced` adds a pixel
// layer above the selection, and nothing keeps the picture after it, so `placedSelection` is always nil
// and `placeFillBox` refuses a fill. Until PP-5 builds the bodies, `placeHelp` says placing isn't built
// with an image open, and the edits throw `PlaceRules.notBuilt`. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension PhotoWorkspace: PlacedImageTarget {
    /// Why nothing can be placed: no image open, or the stub's not-built reason (PP-5 drops it).
    static let noPlaceImage = "Open or make an image to place into.", placeNotBuilt = "Placing images isn't built yet."
    /// Why `place.replace`, `place.reset-size`, `place.focus` and a fill can't run in Photo.
    static let placedBecomesPixels = "A placed image becomes pixels in Photo."

    /// Why nothing can be placed now; nil when it can. Stub: with an image open it says placing isn't built.
    public var placeHelp: String? {
        canvas == nil ? Self.noPlaceImage : Self.placeNotBuilt
    }

    /// What a new image fits inside: the canvas, or an empty rect with no image open.
    public var placeCanvas: Rect {
        guard let canvas else { return Rect(minX: 0, minY: 0, maxX: 0, maxY: 0) }
        return Rect(minX: 0, minY: 0, maxX: Double(canvas.width), maxY: Double(canvas.height))
    }

    /// Always nil: a Photo layer holds pixels, never a box a picture fills.
    public var placeFillBox: Rect? { nil }

    /// PNG and JPEG; Photo doesn't rasterize SVG yet.
    public var placeFormats: Set<PlacedFormat> { [.png, .jpeg] }

    /// Always nil: a placed image becomes pixels, so no layer keeps its picture.
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? { nil }

    /// A PNG's or JPEG's pixel size from its header. Stub: refuses; PP-5 reads it through CoreRaster.
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size {
        throw PlaceRules.notBuilt
    }

    /// Adds a pixel layer showing `asset` fitted to `image.box`, above the selection, selected, as one step.
    /// Stub: refuses; PP-5 builds it on the insert Paste uses.
    public mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String {
        throw PlaceRules.notBuilt
    }

    /// Photo keeps no picture to change, so this always refuses.
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws {
        throw CatalogError.unavailable(id: "place", why: Self.placedBecomesPixels)
    }
}
