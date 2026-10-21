// FlarePlace+Kernel.swift (svg-place PF-1 stubs, PF-5 bodies): Flare's workspace is a kernel
// `PlacedImageTarget`, so the place commands in `PlaceCommands` bring an SVG into the edited scene the way the
// other apps place pictures. Flare draws no pixels, so it takes SVG only and `rasterSize` refuses. PF-5 turns the
// SVG's groups into layers through `SVGImport`, fitted inside the scene as one undo step, and fills `placeReport`.
// Until then the edits throw a not-built refusal and change nothing. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel

extension FlareWorkspace: PlacedImageTarget {
    /// The refusal every place edit throws until PF-5 builds it.
    static let placeNotBuilt = CatalogError.notBuilt(id: "place.image", feature: "svg-place PF-5")

    /// Why nothing can be placed now: no animation or scene open; nil when one is.
    public var placeHelp: String? {
        document == nil || selectedScene == nil ? FlareLayerError.noDocument.message : nil
    }

    /// What a placed drawing fits inside: the edited scene's frame, or an empty rect with none open.
    public var placeCanvas: Rect {
        guard let scene = selectedScene else { return Rect(minX: 0, minY: 0, maxX: 0, maxY: 0) }
        return Rect(minX: 0, minY: 0, maxX: scene.width, maxY: scene.height)
    }

    /// Flare has no box a picture fills, so a fill always refuses.
    public var placeFillBox: Rect? { nil }

    /// SVG only: Flare draws vectors, not pixels.
    public var placeFormats: Set<PlacedFormat> { [.svg] }

    /// A placed SVG becomes plain layers, so no layer is ever a placed picture.
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? { nil }

    /// Flare reads no raster files, so every format refuses.
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size {
        throw CatalogError.unavailable(id: "place.image", why: PlaceRules.formatHelp)
    }

    /// Adds the SVG's groups as layers fitted in `image.box`, as one step. Stub: refuses; PF-5 builds it.
    public mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String {
        throw Self.placeNotBuilt
    }

    /// Flare keeps no placed picture to edit, so this always refuses.
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws {
        throw Self.placeNotBuilt
    }

    /// What the last place did ("Placed logo.svg: 2 layers. Skipped filter (3)."); nil before a place. Stub: nil.
    public var placeReport: String? { nil }
}
