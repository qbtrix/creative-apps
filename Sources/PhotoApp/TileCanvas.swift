// TileCanvas.swift: the canvas picture as one Core Animation layer per
// 256 px tile, so a brush event replaces only the tiles it dirtied.
// CanvasTiles keeps each tile's image (premultiplied sRGB, what Core Animation
// draws without converting) and hands a PhotoTileUpdate's tiles to the view
// showing them, without going through SwiftUI. TileCanvasView lays the tile
// layers in a container scaled by the zoom and turned by the Straighten
// preview's angle; tile edges have no antialiasing, so abutting tiles leave no
// seam. AppKit's `cacheDisplay` (the snapshots) draws through `draw(_:)`,
// not the layers, so that draws the same tiles the same way. Mouse input stays
// with CanvasViewport, which owns focus and Space-pan: the view never takes a
// click (`hitTest` is nil). Presentation state only.
import AppKit
import PhotoModel
import SwiftUI

@MainActor final class CanvasTiles {
    private(set) var width = 0, height = 0
    private(set) var images: [PixelRect: CGImage] = [:]
    /// Bytes of the images the last update handed to the view.
    private(set) var handedBytes = 0
    private weak var view: TileCanvasView?

    /// Keeps `update`'s tiles, dropping every older one when it is complete
    /// or the canvas changed size, and shows them in the attached view.
    func apply(_ update: PhotoTileUpdate) {
        let restart = update.isComplete || update.width != width || update.height != height
        if restart { (width, height, images) = (update.width, update.height, [:]) }
        handedBytes = 0
        var changed: [PixelRect: CGImage] = [:]
        for tile in update.tiles {
            guard let image = Self.image(tile) else { continue }
            changed[tile.rect] = image
            handedBytes += image.bytesPerRow * image.height
        }
        images.merge(changed) { $1 }
        view?.show(changed, restart: restart, width: width, height: height)
    }

    /// Clears the picture (no image open).
    func clear() {
        (width, height, images, handedBytes) = (0, 0, [:], 0)
        view?.show([:], restart: true, width: 0, height: 0)
    }

    /// Shows the picture in `view` from now on; a view already attached keeps its layers.
    func attach(_ view: TileCanvasView) {
        guard self.view !== view else { return }
        self.view = view
        view.show(images, restart: true, width: width, height: height)
    }

    /// A tile's bytes as an image; nil only if CoreGraphics refuses them.
    nonisolated static func image(_ tile: PhotoTileUpdate.Tile) -> CGImage? {
        CanvasRenderer.image(rgba8: tile.rgba8, width: tile.rect.width, height: tile.rect.height, alpha: .premultipliedLast)
    }

    /// Every tile of `workspace`, made in place (snapshots); nil with no image open.
    static func complete(_ workspace: PhotoWorkspace) throws -> CanvasTiles? {
        guard workspace.canvas != nil else { return nil }
        let tiles = CanvasTiles()
        tiles.apply(try PhotoRenderer.completeUpdate(workspace))
        return tiles
    }
}

/// The tile layers in a container that the zoom scales and the Straighten
/// preview turns about the picture's centre. Unflipped, like its layers, so a
/// tile at canvas row y sits at height - maxY.
final class TileCanvasView: NSView {
    private let container = CALayer()
    private var layers: [PixelRect: CALayer] = [:]
    private var images: [PixelRect: CGImage] = [:]
    private var size = CGSize.zero
    private var degrees = 0.0
    private var zoom = 1.0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        container.anchorPoint = .zero
        container.actions = ["sublayers": NSNull(), "transform": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer?.addSublayer(container)
    }

    required init?(coder: NSCoder) { nil }

    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {}
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func configure(zoom: Double, degrees: Double) {
        guard zoom != self.zoom || degrees != self.degrees else { return }
        (self.zoom, self.degrees) = (zoom, degrees)
        let filter: CALayerContentsFilter = zoom >= 2 ? .nearest : .linear
        for layer in layers.values { layer.magnificationFilter = filter }
        needsLayout = true
    }

    /// Replaces the contents of the `changed` tiles' layers, or every layer
    /// with `restart`, in one transaction with no animation.
    func show(_ changed: [PixelRect: CGImage], restart: Bool, width: Int, height: Int) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if restart {
            for layer in layers.values { layer.removeFromSuperlayer() }
            (layers, images) = ([:], [:])
            size = CGSize(width: width, height: height)
            container.bounds = CGRect(origin: .zero, size: size)
        }
        for (rect, image) in changed {
            let layer = layers[rect] ?? newLayer(rect)
            layer.contents = image
            images[rect] = image
        }
        CATransaction.commit()
        if restart { needsLayout = true }
    }

    private func newLayer(_ rect: PixelRect) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(x: rect.x, y: Int(size.height) - rect.maxY, width: rect.width, height: rect.height)
        layer.edgeAntialiasingMask = []
        layer.magnificationFilter = zoom >= 2 ? .nearest : .linear
        layer.minificationFilter = .trilinear
        container.addSublayer(layer)
        layers[rect] = layer
        return layer
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        container.position = .zero
        container.setAffineTransform(placement)
        CATransaction.commit()
    }

    /// Canvas pixels to view points: scaled to the bounds, turned about the centre.
    private var placement: CGAffineTransform {
        guard size.width > 0, size.height > 0 else { return .identity }
        let (w, h) = (bounds.width, bounds.height)
        // Clockwise on screen, as SwiftUI's rotationEffect; unflipped y goes up.
        return CGAffineTransform(scaleX: w / size.width, y: h / size.height)
            .concatenating(CGAffineTransform(translationX: -w / 2, y: -h / 2))
            .concatenating(CGAffineTransform(rotationAngle: -degrees * .pi / 180))
            .concatenating(CGAffineTransform(translationX: w / 2, y: h / 2))
    }

    /// The same tiles through Core Graphics, for `cacheDisplay`.
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.concatenate(placement)
        context.interpolationQuality = zoom >= 2 ? .none : .high
        for (rect, image) in images {
            context.draw(
                image, in: CGRect(x: rect.x, y: Int(size.height) - rect.maxY, width: rect.width, height: rect.height))
        }
    }
}

/// The tile canvas in SwiftUI: CanvasTiles' picture at the size SwiftUI gives it.
struct TileCanvas: NSViewRepresentable {
    let tiles: CanvasTiles
    var zoom: Double
    var degrees: Double

    func makeNSView(context: Context) -> TileCanvasView {
        let view = TileCanvasView()
        view.configure(zoom: zoom, degrees: degrees)
        tiles.attach(view)
        return view
    }

    func updateNSView(_ view: TileCanvasView, context: Context) {
        view.configure(zoom: zoom, degrees: degrees)
        tiles.attach(view)
    }
}
