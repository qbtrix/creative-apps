// TileCanvas.swift: the canvas picture, one 256 px tile at a time, so a brush
// event replaces only the tiles it dirtied. CanvasTiles keeps each tile's
// image (premultiplied sRGB, what Core Animation draws without converting) and
// hands a PhotoTileUpdate's tiles straight to the SuiteUI CanvasHostView
// showing them, without going through SwiftUI. That view (EmbeddedCanvasHost,
// inside the CanvasViewport) draws them as tile layers on the CPU path or
// through its CAMetalLayer on the GPU path, as View > Rendering says, turned
// by the Straighten preview's angle. Mouse input stays with CanvasViewport,
// which owns focus and Space-pan: the embedded view never takes a click.
// Presentation state only.
import AppKit
import PhotoModel
import SuiteUI
import SwiftUI

@MainActor final class CanvasTiles {
    private(set) var width = 0, height = 0
    private(set) var images: [PixelRect: CGImage] = [:]
    /// Bytes of the images the last update handed to the view.
    private(set) var handedBytes = 0
    private weak var view: CanvasHostView?

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
        view?.show(Shown(width: width, height: height, images: changed))
    }

    /// Clears the picture (no image open).
    func clear() {
        (width, height, images, handedBytes) = (0, 0, [:], 0)
        view?.show(Shown(width: 0, height: 0, images: [:]))
    }

    /// Shows the picture in `view` from now on; a view already attached keeps its layers.
    func attach(_ view: CanvasHostView) {
        guard self.view !== view else { return }
        self.view = view
        view.show(Shown(width: width, height: height, images: images))
    }

    /// Tiles for the host: on a new size it shows them as the whole picture, else replaces just them.
    struct Shown: CanvasContentProviding {
        let width: Int, height: Int
        let images: [PixelRect: CGImage]
        var documentSize: CGSize { CGSize(width: width, height: height) }
        func tiles(dirtyOnly: Bool) -> [CanvasTile] {
            images.map { CanvasTile(rect: CanvasTileRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height), image: $1) }
        }
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
