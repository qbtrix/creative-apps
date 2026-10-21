// PhotoPlace+Kernel.swift (place-image PP-1 stubs, PP-5 bodies): Photo's workspace is a kernel
// `PlacedImageTarget`, so the place commands in `PlaceCommands` put a PNG or JPEG into an open image the
// way the other apps place theirs. A placed image becomes pixels in Photo: `insertPlaced` adds a pixel
// layer above the selection, and nothing keeps the picture after it, so `placedSelection` is always nil
// and `placeFillBox` refuses a fill. The size comes from the file's header (CoreRaster's `PNG.info` and
// `JPEG.info`), the pixels from CoreRaster's decode, downscaled (lanczos3) when the fitted box is smaller,
// and the layer goes in through `insertPixelLayer`, the insert Paste uses. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteKernel

extension PhotoWorkspace: PlacedImageTarget {
    /// Why nothing can be placed: no image open.
    static let noPlaceImage = "Open or make an image to place into."
    /// Why a file that isn't a PNG or JPEG isn't placed, and why one that doesn't decode isn't.
    static let placeFormatHelp = "Photo places PNG or JPEG files.", cantPlace = "Can't place this image."
    /// Why `place.replace`, `place.reset-size`, `place.focus` and a fill can't run in Photo.
    static let placedBecomesPixels = "A placed image becomes pixels in Photo."

    /// Why nothing can be placed now; nil when it can: an image is open.
    public var placeHelp: String? {
        canvas == nil ? Self.noPlaceImage : nil
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

    /// A PNG's or JPEG's pixel size from its header, without decoding the pixels; SVG is refused.
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size {
        let size: (width: Int, height: Int)
        switch format {
        case .png:
            guard let info = try? PNG.info(data) else { throw Self.placeFailed }
            size = (info.width, info.height)
        case .jpeg:
            guard let info = try? JPEG.info(data) else { throw Self.placeFailed }
            size = (info.width, info.height)
        case .svg:
            throw CatalogError.unavailable(id: "place.image", why: Self.placeFormatHelp)
        }
        return Size(width: Double(size.width), height: Double(size.height))
    }

    /// Adds a pixel layer showing `asset` in `image.box`, above the selection, selected, as one step titled
    /// `name`. The layer takes the file's name without its extension. A box smaller than the file is a
    /// downscale (never up), with "Placed at <n>%." in the status line; a file placed whole clears it.
    public mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String {
        if let help = placeHelp { throw CatalogError.unavailable(id: "place.image", why: help) }
        guard placeFormats.contains(asset.format) else {
            throw CatalogError.unavailable(id: "place.image", why: Self.placeFormatHelp)
        }
        let box = image.box
        let width = max(Int(box.width.rounded()), 1), height = max(Int(box.height.rounded()), 1)
        guard var buffer = try? CoreRasterImageCodec.read(asset.data) else { throw Self.placeFailed }
        let scaled = width < buffer.width || height < buffer.height
        if scaled {
            guard let resized = try? buffer.resized(width: width, height: height, filter: .lanczos3) else {
                throw Self.placeFailed
            }
            buffer = resized
        }
        let id = insertPixelLayer(TiledPixels(buffer), named: Self.placedLayerName(asset.name),
                                  x: Int(box.minX.rounded()), y: Int(box.minY.rounded()), step: name)
        let natural = max(asset.natural.width, 1)
        statusMessage = scaled ? "Placed at \(Int((box.width / natural * 100).rounded()))%." : nil
        return id
    }

    /// Photo keeps no picture to change, so this always refuses.
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws {
        throw CatalogError.unavailable(id: "place", why: Self.placedBecomesPixels)
    }

    /// A file that claims PNG or JPEG but doesn't read as one.
    static let placeFailed = CatalogError.failed(id: "place.image", message: cantPlace)

    /// "logo.png" places as "logo"; a name with nothing before its extension places as "Placed Layer".
    static func placedLayerName(_ file: String) -> String {
        let stem = file.lastIndex(of: ".").map { String(file[..<$0]) } ?? file
        return stem.isEmpty ? "Placed Layer" : stem
    }
}
