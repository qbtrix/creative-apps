// CanvasTileSet.swift: the canvas host's tile path (canvas-host, CH-8). One
// Core Animation layer per content tile under one container layer, so an
// update replaces only the layers of the tiles it carries. A tile whose image
// is the one its layer already shows is clean and left alone; a nil image
// clears its layer. A new document size restarts the set: every old layer
// goes, so no stale tile survives a resize. Each image reaches its layer as
// premultiplied 8-bit sRGB, what Core Animation draws without converting; an
// image in any other form is redrawn once into that form. `handedBytes` is
// the byte count of the images the last update handed to layers. The
// container's geometry is flipped, so a tile's frame is its pixel rect, y
// running down from the document's top. CH-9 puts the container under
// CanvasHostView. Presentation state only. macOS only (QuartzCore).
import CoreGraphics
import Foundation
import QuartzCore

@MainActor
public final class CanvasTileSet {
    /// What one `apply` did.
    public struct Update: Equatable, Sendable {
        /// Layers whose contents changed.
        public var replaced: Int
        /// The document size changed, so every old layer was dropped first.
        public var restarted: Bool
    }

    /// The layer the tile layers sit in, document pixels with y down.
    public let container = CALayer()
    public private(set) var documentSize = CGSize.zero
    /// Bytes of the images the last `apply` handed to layers.
    public private(set) var handedBytes = 0
    private var layers: [CanvasTileRect: CALayer] = [:]
    private var images: [CanvasTileRect: CGImage] = [:]
    /// The image each tile was given, before it was made premultiplied sRGB: a repeat of it is clean.
    private var given: [CanvasTileRect: CGImage] = [:]

    public init() {
        container.anchorPoint = .zero
        container.isGeometryFlipped = true
        container.actions = ["sublayers": NSNull(), "bounds": NSNull(), "position": NSNull()]
    }

    /// The tile layers, one per rect shown.
    public var layerCount: Int { layers.count }

    /// The image the tile at `rect` shows, premultiplied sRGB; nil when it has none.
    public func image(at rect: CanvasTileRect) -> CGImage? { images[rect] }

    /// Shows `tiles` on a document of `size`. A size other than the current one
    /// restarts the set; otherwise only the carried tiles that changed are replaced.
    @discardableResult
    public func apply(_ tiles: [CanvasTile], documentSize size: CGSize) -> Update {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let restarted = size != documentSize
        if restarted {
            for layer in layers.values { layer.removeFromSuperlayer() }
            (layers, images, given) = ([:], [:], [:])
            documentSize = size
            container.bounds = CGRect(origin: .zero, size: size)
        }
        handedBytes = 0
        var replaced = 0
        for tile in tiles {
            if layers[tile.rect] != nil, given[tile.rect] === tile.image { continue }
            let image = tile.image.flatMap(Self.premultipliedSRGB)
            let layer = layers[tile.rect] ?? newLayer(tile.rect)
            layer.contents = image
            images[tile.rect] = image
            given[tile.rect] = tile.image
            replaced += 1
            if let image { handedBytes += image.bytesPerRow * image.height }
        }
        return Update(replaced: replaced, restarted: restarted)
    }

    private func newLayer(_ rect: CanvasTileRect) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        layer.edgeAntialiasingMask = []
        layer.actions = ["contents": NSNull()]
        container.addSublayer(layer)
        layers[rect] = layer
        return layer
    }

    /// Whether `image` is 8-bit sRGB with premultiplied alpha.
    public nonisolated static func isPremultipliedSRGB(_ image: CGImage) -> Bool {
        let premultiplied = image.alphaInfo == .premultipliedLast || image.alphaInfo == .premultipliedFirst
        let name = image.colorSpace?.name.map { $0 as String }
        return premultiplied && image.bitsPerComponent == 8 && name == (CGColorSpace.sRGB as String)
    }

    /// `image` as premultiplied 8-bit sRGB: itself when it already is, else
    /// redrawn once; nil only when CoreGraphics refuses it.
    public nonisolated static func premultipliedSRGB(_ image: CGImage) -> CGImage? {
        if isPremultipliedSRGB(image) { return image }
        let (width, height) = (image.width, image.height)
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
