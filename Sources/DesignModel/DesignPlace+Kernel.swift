// DesignPlace+Kernel.swift (placed-images PD-1 stubs, PD-5 bodies): Design's workspace is a kernel
// `PlacedImageTarget`, so the place commands in `PlaceCommands` add and edit pictures the way the other
// apps do. A rectangle or frame keeps the kernel's `PlacedAsset` and a focus on the node; its `frame` is
// the picture's `PlacedImage.box`, so the frame stays the one source of the box. `rasterSize` reads a PNG's
// or JPEG's header through CoreRaster, so the CLI places on Linux. A new picture is a rectangle inside the
// selected frame (else the frame its box's centre falls in, fitted to it, else the page's top), named after the file; a
// fill puts the picture into the one selected rectangle or frame, refused with its lock help. Every edit is one step,
// and steps under one drag token on one layer fold into one. The fit, the crop and the reset are the
// kernel's (`PlaceRules`, run by `PlaceCommands`). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteKernel

extension DesignWorkspace: PlacedImageTarget {
    /// Why nothing can be placed: no page open; why a picture edit can't run: no rectangle or frame to hold it.
    static let noPlacePage = "Open a file to place a picture.", noPicture = "Select a rectangle or frame with a picture."
    static let placeFinishText = "Finish editing the text first."
    /// Why an SVG has no pixel size to read (`PlaceCommands` sizes it from its own flattening).
    static let noRasterSize = "An SVG has no pixel size."

    /// Why nothing can be placed now; nil when it can: no page open, a text being edited, or the selected frame
    /// (where the picture would land) locked, with its lock help. A locked picture gates only its own edits.
    public var placeHelp: String? {
        guard selectedPage != nil else { return Self.noPlacePage }
        guard editingTextID == nil else { return Self.placeFinishText }
        return placeParent.flatMap(lockHelp)
    }

    /// What a new picture fits inside: the selected frame, else the selected page, else an empty rect.
    public var placeCanvas: Rect {
        if let id = placeParent, let frame = selectedPage?.nodes.node(id) { return frame.frame.kernelRect }
        guard let page = selectedPage else { return Rect(minX: 0, minY: 0, maxX: 0, maxY: 0) }
        return Rect(minX: 0, minY: 0, maxX: page.frameWidth, maxY: page.frameHeight)
    }

    /// The box a fill fills: the frame of the one selected rectangle or frame; nil refuses the fill. A locked one
    /// keeps its box, so `setPlaced` refuses the fill with the lock as the reason.
    public var placeFillBox: Rect? {
        guard selectedNodeIDs.count == 1, let node = selectedNode, node.kind.holdsPicture else { return nil }
        return node.frame.kernelRect
    }

    /// Every case of `PlacedFormat`.
    public var placeFormats: Set<PlacedFormat> { Set(PlacedFormat.allCases) }

    /// The selected node's picture, its box the node's frame; nil when it shows none.
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? {
        guard let node = selectedNode, let asset = node.placedAsset else { return nil }
        return (node.id, PlacedImage(assetID: asset.id, box: node.frame.kernelRect, focus: node.placedFocus), asset)
    }

    /// A PNG's or JPEG's pixel size from its header, through CoreRaster; an SVG has no pixels and throws.
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size {
        guard format != .svg else { throw CatalogError.failed(id: "place.image", message: Self.noRasterSize) }
        if format == .png {
            let info = try PNG.info(data)
            return Size(width: Double(info.width), height: Double(info.height))
        }
        let info = try JPEG.info(data)
        return Size(width: Double(info.width), height: Double(info.height))
    }

    /// Adds a rectangle showing `asset` in `image.box`, named after the file without its extension, inside the
    /// selected frame (else the unlocked frame the box's centre falls in, refitted inside it, else at the page's
    /// top), selected, as one step named `name`.
    public mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String {
        if let help = placeHelp { throw CatalogError.unavailable(id: "place.image", why: help) }
        let box = DesignRect(image.box)
        let centre = DesignPoint(x: box.x + box.width / 2, y: box.y + box.height / 2)
        let landing = placeParent == nil ? selectedPage?.nodes.deepestFrame(containing: centre) : nil
        let parent = placeParent ?? landing
        // The fit and the landing frame are one frame: a box fitted to the page refits inside the frame it lands in.
        let frame = landing.flatMap { selectedPage?.nodes.node($0) }.map {
            DesignRect(PlaceRules.fitted(natural: asset.natural, in: $0.frame.kernelRect, at: Point(x: centre.x, y: centre.y)))
        } ?? box
        let before = snapshot
        let id = try insertNode(.rectangle, frame: frame, in: parent)
        _ = pages.update(id) { ($0.name, $0.placedAsset, $0.placedFocus) = (Self.placedName(asset.name), asset, image.focus) }
        record(name, before: before)
        return id
    }

    /// Sets the selected rectangle's or frame's picture (`asset`, else the one it shows), box and focus as one
    /// step named `name`; steps under one `drag` on that layer fold into one. A locked layer, another kind, or
    /// no asset for a layer without a picture refuses and changes nothing.
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws {
        guard let node = selectedNode, node.kind.holdsPicture, let shown = asset ?? node.placedAsset else {
            throw CatalogError.unavailable(id: "place", why: Self.noPicture)
        }
        if let help = lockHelp(node.id) { throw CatalogError.unavailable(id: "place", why: help) }
        let before = snapshot
        _ = pages.update(node.id) {
            $0.frame = DesignRect(image.box)
            ($0.placedAsset, $0.placedFocus) = (shown, image.focus)
        }
        record(name, before: before, coalescing: drag.map { DesignEdit.runKey("place-" + $0, [node.id]) })
    }

    /// The selected frame a new picture lands in; nil when no frame is selected.
    var placeParent: String? {
        guard let node = selectedNode, node.kind == .frame else { return nil }
        return node.id
    }

    /// "photo.png" places as "photo"; a name with nothing before its extension places as "Image".
    static func placedName(_ file: String) -> String {
        let stem = file.lastIndex(of: ".").map { String(file[..<$0]) } ?? file
        return stem.isEmpty ? "Image" : stem
    }
}
