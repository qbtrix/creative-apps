// DesignRaster.swift: what a PNG of one planned export item draws (design-export DE-8), so the
// App's DesignRasterizer only renders. The item comes from the plan (exportPlan): its size in
// points and its pixelWidth and pixelHeight. The nodes are the ones exportSVG writes for it:
// the page's nodes for the page item, else that layer with its subtree, found in the layer
// tree and moved with it (DesignNode.translate) so the box's origin is (0, 0). They come back
// as a page the item's whole-point size, which the canvas's own painter draws. A layer drawn
// alone loses its ancestors' opacity and backdrop, as its SVG does. A size of less than one
// point, pixels that are not the whole points times one scale, or a side over `maxSide`
// pixels is refused. `exportRaster(_:at:)` draws the page as it shows at a frame (one-document OD-9). Linux-safe.

/// The artwork and bitmap size of one planned raster item.
public struct DesignRaster: Sendable, Equatable {
    /// The longest side in pixels a raster draws; keeps the bitmap allocation bounded.
    public static let maxSide = 16_384

    /// The item's nodes moved to the origin, on a page the item's whole-point size.
    public let artwork: DesignPage
    /// The plan's pixel size.
    public let pixelWidth: Int
    public let pixelHeight: Int
    /// Pixels per point: the plan's pixel width over the item's whole-point width.
    public let scale: Int
}

/// Why an item can't be rasterized.
public enum DesignRasterRefusal: Error, Equatable, Sendable, CustomStringConvertible {
    /// The item's node is not on the page.
    case unknownID(String)
    /// The size is under a point, the pixels aren't whole points times one scale, or a side is over `maxSide`.
    case invalidSize

    /// Plain words for a command catalog's refusal (the CLI, MCP), never the case name.
    public var description: String {
        switch self {
        case .unknownID(let id): DesignRefusal.unknownID(id).help
        case .invalidSize: "That size can't be drawn: use whole points, at most \(DesignRaster.maxSide) pixels a side."
        }
    }
}

extension DesignPage {
    /// The raster of `item` on this page: the page item draws every node, a layer its own subtree.
    public func raster(_ item: DesignExportItem) throws(DesignRasterRefusal) -> DesignRaster {
        let origin: DesignPoint, drawn: [DesignNode]
        if item.nodeID == id {
            (origin, drawn) = (DesignPoint(x: 0, y: 0), nodes)
        } else {
            guard let node = nodes.node(item.nodeID) else { throw .unknownID(item.nodeID) }
            (origin, drawn) = (DesignPoint(x: -node.frame.x, y: -node.frame.y), [node])
        }
        func whole(_ value: Double) -> Int { value.isFinite ? Int(Swift.max(Swift.min(value, 1e9), -1e9).rounded()) : 0 }
        let (w, h) = (whole(item.width), whole(item.height))
        guard origin.isFinite, w >= 1, h >= 1, item.pixelWidth % w == 0, item.pixelHeight % h == 0 else { throw .invalidSize }
        let scale = item.pixelWidth / w
        guard scale >= 1, item.pixelHeight / h == scale,
              item.pixelWidth <= DesignRaster.maxSide, item.pixelHeight <= DesignRaster.maxSide
        else { throw .invalidSize }
        let moved = drawn.map { node in
            var node = node
            node.translate(by: origin)
            return node
        }
        let artwork = DesignPage(id: item.nodeID, name: name, frameWidth: Double(w), frameHeight: Double(h), nodes: moved)
        return DesignRaster(artwork: artwork, pixelWidth: item.pixelWidth, pixelHeight: item.pixelHeight, scale: scale)
    }
}

extension DesignWorkspace {
    /// The raster of one planned item on the selected page at the rest pose (see `DesignPage.raster`).
    public func exportRaster(_ item: DesignExportItem) throws(DesignRasterRefusal) -> DesignRaster { try exportRaster(item, at: nil) }

    /// The raster of `item` with the page as it shows at `frame` (nil: the rest pose).
    public func exportRaster(_ item: DesignExportItem, at frame: Int?) throws(DesignRasterRefusal) -> DesignRaster {
        guard let page = selectedPage?.shown(at: frame) else { throw .unknownID(item.nodeID) }
        return try page.raster(item)
    }
}
