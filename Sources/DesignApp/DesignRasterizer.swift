// DesignRasterizer.swift: the PNG of one planned export item (design-export DE-8; blueprint
// F6, #418), drawn off the window from the canvas's own painter. The item's box is its node's
// frame, or the whole page when `nodeID` is the page's id. The nodes painted are the page's
// painted list (DesignPage.painted: paint order, hidden subtrees gone, opacity and backdrop
// from the ancestors) kept to the item's subtree, moved so the box's origin is (0, 0), and
// drawn by DesignArtwork at zoom 1 through ImageRenderer at `scale` (1, 2 or 3). The image is
// redrawn into an 8-bit sRGB bitmap with alpha, so nothing painted stays transparent, and
// ImageIO writes it as PNG. The size is whole points times the scale, as the plan's
// pixelWidth and pixelHeight. Nothing here touches a window or the Model's state, so no
// window body runs during a write. A missing item, a size that is empty or too large, and a
// render or encode that fails each throw a DesignRasterizerError. PDF is DE-9. macOS only.
import CoreGraphics
import DesignModel
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum DesignRasterizerError: Error, Equatable {
    /// The item's node is not on the page.
    case noSuchItem(String)
    /// The box times the scale is empty, not finite or longer than `DesignRasterizer.maxSide`.
    case invalidSize
    /// ImageRenderer or CoreGraphics made no image.
    case renderFailed
    /// ImageIO could not write the PNG.
    case encodeFailed
}

/// PNG (and, from DE-9, PDF) of planned items, drawn from DesignArtwork off the window.
enum DesignRasterizer {
    /// The longest side in pixels this draws; keeps the bitmap allocation bounded.
    static let maxSide = 16_384

    /// The nodes inside the item's box painted at `scale` into an sRGB PNG with alpha.
    @MainActor
    static func png(_ item: DesignExportItem, on page: DesignPage, scale: Int) throws -> Data {
        let (box, painted) = try artwork(item, on: page)
        let k = max(scale, 1)
        let (width, height) = try pixelSize(box, scale: k)
        let view = DesignArtwork(painted: painted, zoom: 1)
            .frame(width: CGFloat(width / k), height: CGFloat(height / k))
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = CGFloat(k)
        renderer.isOpaque = false
        guard let drawn = renderer.cgImage else { throw DesignRasterizerError.renderFailed }
        return try encodePNG(try sRGB(drawn, width: width, height: height))
    }

    /// The item's box in page points, and the page's painted nodes of its subtree moved to the box's origin.
    static func artwork(_ item: DesignExportItem, on page: DesignPage) throws -> (DesignRect, [DesignPainted]) {
        if item.nodeID == page.id {
            return (DesignRect(x: 0, y: 0, width: page.frameWidth, height: page.frameHeight), page.painted)
        }
        guard let node = find(item.nodeID, in: page.nodes) else { throw DesignRasterizerError.noSuchItem(item.nodeID) }
        let ids = subtreeIDs(node)
        let box = node.frame
        let moved = page.painted.filter { ids.contains($0.id) }.map { painted -> DesignPainted in
            var shifted = painted.node
            shifted.frame.x -= box.x
            shifted.frame.y -= box.y
            return DesignPainted(node: shifted, backdrop: painted.backdrop, opacity: painted.opacity)
        }
        return (box, moved)
    }

    /// Whole points of `box` times `scale`, as the plan counts them; throws unless both are in 1...maxSide.
    static func pixelSize(_ box: DesignRect, scale: Int) throws -> (width: Int, height: Int) {
        let w = box.width.rounded(), h = box.height.rounded()
        guard w.isFinite, h.isFinite, w >= 1, h >= 1,
              w * Double(scale) <= Double(maxSide), h * Double(scale) <= Double(maxSide)
        else { throw DesignRasterizerError.invalidSize }
        return (Int(w) * scale, Int(h) * scale)
    }

    private static func find(_ id: String, in nodes: [DesignNode]) -> DesignNode? {
        for node in nodes {
            if node.id == id { return node }
            if let found = find(id, in: node.children) { return found }
        }
        return nil
    }

    private static func subtreeIDs(_ node: DesignNode) -> Set<String> {
        node.children.reduce(into: [node.id]) { $0.formUnion(subtreeIDs($1)) }
    }

    /// `image` drawn into a `width` × `height` 8-bit sRGB bitmap with premultiplied alpha.
    private static func sRGB(_ image: CGImage, width: Int, height: Int) throws -> CGImage {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw DesignRasterizerError.renderFailed }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let out = context.makeImage() else { throw DesignRasterizerError.renderFailed }
        return out
    }

    /// `image` as PNG bytes through ImageIO.
    private static func encodePNG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw DesignRasterizerError.encodeFailed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw DesignRasterizerError.encodeFailed }
        return data as Data
    }
}
