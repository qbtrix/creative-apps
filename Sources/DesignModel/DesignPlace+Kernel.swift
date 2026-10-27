// DesignPlace+Kernel.swift (placed-images PD-1 stubs, PD-5 bodies): Design's workspace is a kernel
// `PlacedImageTarget`, so the place commands in `PlaceCommands` add and edit pictures the way the other
// apps do. A rectangle or frame keeps the kernel's `PlacedAsset` and a focus on the node; its `frame` is
// the picture's `PlacedImage.box`, so the frame stays the one source of the box. `rasterSize` reads a PNG's
// or JPEG's header through CoreRaster, so the CLI places on Linux. Until PD-5 the edits throw
// `PlaceRules.notBuilt`, `placeFillBox` is nil and `placeHelp` says so. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteKernel

extension DesignWorkspace: PlacedImageTarget {
    /// Why nothing can be placed: no page open, or the stub's not-built reason.
    static let noPlacePage = "Open or create a file to place a picture.", placeNotBuilt = "Placing pictures isn't built yet."

    /// Why nothing can be placed now; nil when it can. Stub: with a page open it says placing isn't built;
    /// PD-5 drops that line and adds the locked-parent check.
    public var placeHelp: String? {
        selectedPage == nil ? Self.noPlacePage : Self.placeNotBuilt
    }

    /// What a new picture fits inside: the selected page's frame, or an empty rect with no page.
    /// PD-5 prefers the selected frame, then the frame under the view centre.
    public var placeCanvas: Rect {
        guard let page = selectedPage else { return Rect(minX: 0, minY: 0, maxX: 0, maxY: 0) }
        return Rect(minX: 0, minY: 0, maxX: page.frameWidth, maxY: page.frameHeight)
    }

    /// The one selected unlocked frame or rectangle a fill fills. Stub: nil, so a fill refuses; PD-5 builds it.
    public var placeFillBox: Rect? { nil }

    /// Every case of `PlacedFormat`.
    public var placeFormats: Set<PlacedFormat> { Set(PlacedFormat.allCases) }

    /// The selected node's picture, its box the node's frame; nil when it shows none.
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? {
        guard let node = selectedNode, let asset = node.placedAsset else { return nil }
        return (node.id, PlacedImage(assetID: asset.id, box: node.frame.kernelRect, focus: node.placedFocus), asset)
    }

    /// A PNG's or JPEG's pixel size from its header, through CoreRaster; an SVG has no pixels and throws.
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size {
        guard format != .svg else { throw PlaceRules.notBuilt }
        if format == .png {
            let info = try PNG.info(data)
            return Size(width: Double(info.width), height: Double(info.height))
        }
        let info = try JPEG.info(data)
        return Size(width: Double(info.width), height: Double(info.height))
    }

    /// Adds a rectangle showing `asset` in `image.box`, selected, as one step. Stub: refuses; PD-5 builds it.
    public mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String {
        throw PlaceRules.notBuilt
    }

    /// Sets the selected node's picture and box; steps under one `drag` fold into one. Stub: refuses; PD-5 builds it.
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws {
        throw PlaceRules.notBuilt
    }
}
