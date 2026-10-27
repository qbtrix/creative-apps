// TileCanvas.swift: the canvas picture, one 256 px tile at a time, so a brush
// event replaces only the tiles it dirtied. CanvasTiles keeps each tile's
// image (premultiplied sRGB) and the same pixels as an IOSurface, both made
// off the main thread (`prepare`): a tile layer shows the surface, which Core
// Animation draws as it is, where an sRGB image is colour-converted on the
// main thread at every commit. It
// hands a PhotoTileUpdate's tiles straight to the SuiteUI CanvasHostView
// showing them, without going through SwiftUI. That view (EmbeddedCanvasHost,
// inside the CanvasViewport) draws them as tile layers on the CPU path or
// through its CAMetalLayer on the GPU path, as View > Rendering says, turned
// by the Straighten preview's angle. On the resident GPU path
// (`residentTarget`) the renderer writes the picture into the view's Metal
// presenter's texture instead, and an update brings no tiles, only the
// present; its target (SuiteImaging's ImagingGPU.Target) also runs a tone
// program in that write, the live route's one pass per slider step. A Free Transform drag's lifted layer
// goes to the view's lift (`lift`, `moveLift`, `dropLift`). Mouse input stays with CanvasViewport,
// which owns focus and Space-pan: the embedded view never takes a click.
// Presentation state only.
import AppKit
import CoreRaster
import IOSurface
import SuiteImaging
import PhotoModel
import SuiteUI
import SwiftUI

@MainActor final class CanvasTiles {
    private(set) var width = 0, height = 0
    /// The presenter texture the last resident target wrote into; a different one starts empty.
    private var targetTexture: ObjectIdentifier?
    private(set) var images: [PixelRect: CGImage] = [:]
    /// The tiles' IOSurfaces, which the view's tile layers show.
    private var surfaces: [PixelRect: IOSurface] = [:]
    /// Bytes of the images the last update handed to the view.
    private(set) var handedBytes = 0
    private weak var view: CanvasHostView?

    /// Keeps `update`'s tiles, dropping every older one when it is complete
    /// or the canvas changed size, and shows them in the attached view.
    /// `prepared` holds the tiles' images and surfaces made off the main
    /// thread (`prepare`); without it they are made here.
    func apply(_ update: PhotoTileUpdate, prepared: [PixelRect: Prepared]? = nil) {
        let restart = update.isComplete || update.width != width || update.height != height
        if restart { (width, height, images, surfaces) = (update.width, update.height, [:], [:]) }
        let made = prepared ?? Self.prepare(update)
        handedBytes = 0
        var changed: [PixelRect: CGImage] = [:]
        for (rect, tile) in made {
            changed[rect] = tile.image
            surfaces[rect] = tile.surface
            handedBytes += tile.image.bytesPerRow * tile.image.height
        }
        images.merge(changed) { $1 }
        view?.show(Shown(width: width, height: height, images: changed, surfaces: surfaces))
    }

    /// A tile ready for the view: its image, and the same pixels as an IOSurface for its layer.
    struct Prepared: @unchecked Sendable {
        let image: CGImage
        let surface: IOSurface?
    }

    /// `update`'s tiles as images and IOSurfaces, made in parallel on the calling thread. The renderer calls
    /// it off the main thread: a surface is what keeps a commit from colour-converting every tile there.
    nonisolated static func prepare(_ update: PhotoTileUpdate) -> [PixelRect: Prepared] {
        let tiles = update.tiles
        let made = UnsafeMutableBufferPointer<Prepared?>.allocate(capacity: tiles.count)
        made.initialize(repeating: nil)
        defer { made.deallocate() }
        DispatchQueue.concurrentPerform(iterations: tiles.count) { i in
            let tile = tiles[i]
            guard let image = image(tile) else { return }
            made[i] = Prepared(image: image, surface: CanvasTile.surface(
                premultipliedRGBA: tile.rgba8, width: tile.rect.width, height: tile.rect.height))
        }
        var out: [PixelRect: Prepared] = [:]
        for (tile, prepared) in zip(tiles, made) { out[tile.rect] = prepared }
        return out
    }

    /// Where a resident GPU render writes a `width` x `height` picture: the attached view's Metal presenter's
    /// document texture, through `gpu`'s display encode (premultiplied sRGB, no readback). `isNew` when the
    /// texture holds none of the picture yet, so the render must draw every tile. Nil off the Metal path.
    func residentTarget(width: Int, height: Int, on gpu: ImagingGPU.Backend) -> (target: PhotoDisplayTarget, isNew: Bool)? {
        guard let resident = view?.residentTarget(on: gpu, width: width, height: height) else { return nil }
        let id = resident.id
        defer { targetTexture = id }
        let target = PhotoDisplayTarget(
            write: { surface, rect in try resident.write(surface, x: rect.x, y: rect.y) },
            writeToned: { surface, rect, tone in try resident.write(surface, x: rect.x, y: rect.y, tone: tone) })
        return (target, targetTexture != id)
    }

    /// Free Transform's lifted layer (PhotoTransformLift) above the picture in the attached view, at `placement`.
    func lift(_ surface: IOSurface, width: Int, height: Int, opacity: Double, placement: AffineMatrix) {
        view?.lift(surface, size: CGSize(width: width, height: height), opacity: Float(opacity), placement: Self.affine(placement))
    }

    /// Moves the lifted layer to `placement`: a transaction on one CALayer, no pixels.
    func moveLift(_ placement: AffineMatrix) { view?.moveLift(Self.affine(placement)) }

    /// Drops the lifted layer.
    func dropLift() { view?.dropLift() }

    /// A canvas matrix (y down) as Core Graphics' affine transform, the same convention.
    nonisolated static func affine(_ m: AffineMatrix) -> CGAffineTransform {
        CGAffineTransform(a: m.a, b: m.b, c: m.c, d: m.d, tx: m.tx, ty: m.ty)
    }

    /// Clears the picture (no image open).
    func clear() {
        (width, height, images, surfaces, handedBytes) = (0, 0, [:], [:], 0)
        view?.show(Shown(width: 0, height: 0, images: [:], surfaces: [:]))
    }

    /// Shows the picture in `view` from now on; a view already attached keeps its layers.
    func attach(_ view: CanvasHostView) {
        guard self.view !== view else { return }
        self.view = view
        view.show(Shown(width: width, height: height, images: images, surfaces: surfaces))
    }

    /// Tiles for the host: on a new size it shows them as the whole picture, else replaces just them.
    struct Shown: CanvasContentProviding, @unchecked Sendable {
        let width: Int, height: Int
        let images: [PixelRect: CGImage]
        let surfaces: [PixelRect: IOSurface]
        var documentSize: CGSize { CGSize(width: width, height: height) }
        func tiles(dirtyOnly: Bool) -> [CanvasTile] {
            images.map {
                CanvasTile(
                    rect: CanvasTileRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height), image: $1,
                    surface: surfaces[$0])
            }
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
