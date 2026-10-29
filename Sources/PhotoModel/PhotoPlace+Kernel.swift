// PhotoPlace+Kernel.swift (place-image PP-1 stubs, PP-5 bodies): Photo's workspace is a kernel
// `PlacedImageTarget`, so the place commands in `PlaceCommands` put a PNG, JPEG or SVG into an open image the
// way the other apps place theirs. An SVG is drawn at the fitted box's pixel size by SuiteImaging's
// `PlacedVectorPixels` (fills only; strokes and text are not drawn), so it is sharp at document scale. A placed image becomes pixels in Photo: `insertPlaced` adds a pixel
// layer above the selection, and nothing keeps the picture after it, so `placedSelection` is always nil
// and `placeFillBox` refuses a fill. The size comes from the file's header (`SuiteImaging.rasterSize(of:)`),
// the pixels from the workspace's image codec (`readImages(with:)`; the window's is ImageIO),
// read straight at the fitted box's longest side when the box is smaller, so a 12 MP file is never decoded
// whole and resampled on the main actor (#4248). The layer goes in through `insertPixelLayer`, the insert Paste
// uses. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteImaging
import SuiteKernel

extension PhotoWorkspace: PlacedImageTarget {
    /// Why nothing can be placed: no image open.
    static let noPlaceImage = "Open or make an image to place into."
    /// Why a file that isn't a PNG, JPEG or SVG isn't placed, and why one that doesn't decode isn't.
    static let placeFormatHelp = "Photo places PNG, JPEG or SVG files.", cantPlace = "Can't place this image."
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

    /// PNG, JPEG and SVG, which becomes pixels at the size it is placed.
    public var placeFormats: Set<PlacedFormat> { Set(PlacedFormat.allCases) }

    /// Always nil: a placed image becomes pixels, so no layer keeps its picture.
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? { nil }

    /// A PNG's or JPEG's pixel size from its header, without decoding the pixels; an SVG's from its flattening.
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size {
        if format == .svg { return try PlaceRules.vector(data, name: "").size }
        guard let size = SuiteImaging.rasterSize(of: data) else { throw Self.placeFailed }
        return size
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
        let scaled = Double(width) < asset.natural.width.rounded() || Double(height) < asset.natural.height.rounded()
        let drawn = asset.format == .svg
            ? try? TiledPixels(PlacedVectorPixels.pixels(PlaceRules.vector(asset.data, name: asset.name), width: width, height: height))
            : try? Self.placedPixels(asset.data, codec: fileFlow.codec, width: width, height: height, scaled: scaled)
        guard let tiles = drawn else { throw Self.placeFailed }
        let id = insertPixelLayer(tiles, named: Self.placedLayerName(asset.name),
                                  x: Int(box.minX.rounded()), y: Int(box.minY.rounded()), step: name)
        let natural = max(asset.natural.width, 1)
        statusMessage = scaled && asset.format != .svg ? "Placed at \(Int((box.width / natural * 100).rounded()))%." : nil
        return id
    }

    /// Photo keeps no picture to change, so this always refuses.
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws {
        throw CatalogError.unavailable(id: "place", why: Self.placedBecomesPixels)
    }

    /// Reads placed and dropped images through `codec` from now on. The window's is ImageIO, which decodes a large
    /// file straight at the size it is placed at; the default is CoreRaster's, for the headless workspace and Linux.
    public mutating func readImages(with codec: some PhotoImageCodec) {
        fileFlow.codec = codec
    }

    /// A placed file's pixels, `width` x `height`: read through `codec` straight at the box's longest side when
    /// the box is smaller than the file (`scaled`), so a 12 MP JPEG is never decoded whole and resampled on the
    /// main actor, then resampled to the box only if the codec's rounding left it off by a pixel.
    static func placedPixels(_ data: Data, codec: any PhotoImageCodec, width: Int, height: Int,
                             scaled: Bool) throws -> TiledPixels {
        let image = try codec.decode(data, longestSide: scaled ? max(width, height) : nil)
        guard image.width != width || image.height != height else { return try decoded(image) }
        let buffer = try PixelBuffer(rgba8: image.rgba8, width: image.width, height: image.height)
        return TiledPixels(try buffer.resized(width: width, height: height, filter: .lanczos3))
    }

    /// A file that claims PNG or JPEG but doesn't read as one.
    static let placeFailed = CatalogError.failed(id: "place.image", message: cantPlace)

    /// "logo.png" places as "logo"; a name with nothing before its extension places as "Placed Layer".
    static func placedLayerName(_ file: String) -> String {
        let stem = file.lastIndex(of: ".").map { String(file[..<$0]) } ?? file
        return stem.isEmpty ? "Placed Layer" : stem
    }
}
