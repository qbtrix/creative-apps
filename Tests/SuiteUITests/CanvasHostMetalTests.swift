// CanvasHostMetalTests.swift: the canvas host's Metal path (canvas-host CH-10,
// live since render adoption R1): `.gpu` or `.automatic` with a device
// installs a `CAMetalLayer` with a colour space, `.cpu` or a nil device keep
// the tile layers, and switching keeps the overlay on top. The presenter is
// handed every tile on the switch and the changed ones after; the live
// CanvasTilePresenter writes them into its document texture and fills
// drawables. The drawable never has more pixels than the document. On the
// Metal path the tile layers stay empty until the tile path returns, and a
// layout presents only a new picture or a new drawable size. macOS only; the
// GPU cases need a Metal device.
import AppKit
import Metal
import QuartzCore
import Testing

@testable import SuiteUI

@MainActor
@Suite(.serialized) struct CanvasHostMetalTests {
    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil))
    func gpuWithADeviceInstallsAMetalLayerWithAColourSpace() throws {
        let canvas = loadedHost()
        canvas.useRendering(.gpu, device: MTLCreateSystemDefaultDevice(), presenter: ClearingMetalPresenter())
        let metal = try #require(canvas.metalLayer)
        #expect(metal.colorspace != nil)
        #expect(metal.device != nil)
        #expect(!metal.isOpaque, "a clear pixel would draw black over the checkerboard")
        #expect(canvas.container.isHidden)
        #expect(overlayOnTop(canvas))
    }

    @Test func gpuWithNoDeviceKeepsTheTileLayers() {
        let canvas = loadedHost()
        canvas.useRendering(.gpu, device: nil, presenter: ClearingMetalPresenter())
        #expect(canvas.metalLayer == nil)
        #expect(!canvas.container.isHidden)
        #expect(canvas.container.sublayers?.count == 20)
        #expect(overlayOnTop(canvas))
    }

    @Test func cpuKeepsTheTileLayers() {
        let canvas = loadedHost()
        canvas.useRendering(.cpu, device: MTLCreateSystemDefaultDevice(), presenter: ClearingMetalPresenter())
        #expect(canvas.metalLayer == nil)
        #expect(!canvas.container.isHidden)
        #expect(canvas.container.sublayers?.count == 20)
    }

    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil))
    func automaticWithADeviceDrawsOnMetal() throws {
        let canvas = loadedHost()
        canvas.useRendering(.automatic, device: MTLCreateSystemDefaultDevice(), presenter: ClearingMetalPresenter())
        #expect(canvas.metalLayer != nil)
        #expect(canvas.container.isHidden)
    }

    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil))
    func thePresenterGetsEveryTileOnTheSwitchThenTheChangedOnes() throws {
        let canvas = loadedHost()
        let presenter = RecordingPresenter()
        canvas.useRendering(.gpu, device: MTLCreateSystemDefaultDevice(), presenter: presenter)
        #expect(presenter.shown == [20])
        canvas.show(OneTile())
        #expect(presenter.shown == [20, 1])
        canvas.useRendering(.cpu, device: nil, presenter: presenter)
        canvas.show(OneTile())
        #expect(presenter.shown == [20, 1], "a tile on the tile path reached the presenter")
    }

    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil))
    func theTilePresenterWritesTheTilesAndFillsADrawable() throws {
        guard drawablesWork() else { return }
        let canvas = CanvasHostView(frame: CGRect(x: 0, y: 0, width: 960, height: 600))
        canvas.show(GalleryCanvasDocument.make())
        canvas.layoutSubtreeIfNeeded()
        let presenter = CanvasTilePresenter()
        canvas.useRendering(.gpu, device: MTLCreateSystemDefaultDevice(), presenter: presenter)
        #expect(presenter.presented >= 1)
        let texture = try #require(presenter.texture)
        #expect(texture.width == 4096 && texture.height == 2160)
        // The first tile is the accent swatch, opaque: its texel is that colour.
        var texel = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&texel, bytesPerRow: 4, from: MTLRegionMake2D(10, 10, 1, 1), mipmapLevel: 0)
        let hex = SuitePalette.accent.light
        #expect(texel == [UInt8(hex >> 16 & 0xFF), UInt8(hex >> 8 & 0xFF), UInt8(hex & 0xFF), 255])
    }

    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil))
    func theMetalPathLeavesTheTileLayersEmptyUntilTheTilePathReturns() throws {
        let canvas = loadedHost()
        let tileContents = { (canvas.container.sublayers ?? []).compactMap(\.contents).count }
        canvas.useRendering(.gpu, device: MTLCreateSystemDefaultDevice(), presenter: ClearingMetalPresenter())
        let before = tileContents()
        canvas.show(GalleryCanvasDocument.make())
        #expect(tileContents() == before, "a tile layer got an image on the Metal path")
        canvas.useRendering(.cpu, device: nil, presenter: ClearingMetalPresenter())
        #expect(tileContents() == canvas.shown().filter { $0.image != nil }.count)
    }

    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil))
    func aLayoutPresentsOnlyANewPictureOrANewDrawableSize() throws {
        guard drawablesWork() else { return }
        let canvas = CanvasHostView(frame: CGRect(x: 0, y: 0, width: 960, height: 600))
        canvas.show(GalleryCanvasDocument.make())
        canvas.layoutSubtreeIfNeeded()
        let presenter = ClearingMetalPresenter()
        canvas.useRendering(.gpu, device: MTLCreateSystemDefaultDevice(), presenter: presenter)
        let first = presenter.presented
        for _ in 0..<5 { canvas.needsLayout = true; canvas.layoutSubtreeIfNeeded() }
        #expect(presenter.presented == first, "a layout with nothing new presented a drawable")
        canvas.show(OneTile())
        canvas.layoutSubtreeIfNeeded()
        #expect(presenter.presented == first + 1)
        canvas.setFrameSize(CGSize(width: 480, height: 300))
        canvas.layoutSubtreeIfNeeded()
        #expect(presenter.presented == first + 2)
    }

    @Test func theDrawableNeverHasMorePixelsThanTheDocument() {
        let document = CGSize(width: 4096, height: 2160)
        #expect(CanvasHostView.drawableSize(board: CGSize(width: 800, height: 422), scale: 2, document: document)
            == CGSize(width: 1600, height: 844))
        #expect(CanvasHostView.drawableSize(board: CGSize(width: 16384, height: 8640), scale: 2, document: document)
            == document)
        #expect(CanvasHostView.drawableSize(board: .zero, scale: 2, document: .zero) == CGSize(width: 1, height: 1))
    }

    /// Before its first real frame a window lays the host out at zero size: no artboard, so no
    /// drawable. Presenting one (1 x 1) made MPS's Lanczos scale an 8K document into a single pixel,
    /// which asks Metal for a 30238 px temporary texture and aborts the app.
    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil))
    func aHostWithNoArtboardPresentsNothing() throws {
        guard drawablesWork() else { return }
        let canvas = CanvasHostView(frame: .zero)
        canvas.show(EightK())
        let presenter = ClearingMetalPresenter()
        canvas.useRendering(.gpu, device: MTLCreateSystemDefaultDevice(), presenter: presenter)
        canvas.layoutSubtreeIfNeeded()
        #expect(canvas.artboard.isEmpty)
        #expect(presenter.presented == 0, "a host with no artboard presented a drawable")
    }

    @Test func anEmbeddedHostFillsItsBoundsAndTakesNoClick() {
        let canvas = loadedHost()
        canvas.isEmbedded = true
        #expect(canvas.artboard == canvas.bounds)
        #expect(canvas.hitTest(CGPoint(x: 480, y: 300)) == nil)
        // The viewport's container is the one `suite.canvas` element.
        #expect(!canvas.isAccessibilityElement())
        canvas.updateLayer()
        #expect(canvas.layer?.backgroundColor == nil && canvas.container.backgroundColor == nil)
    }

    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil))
    func switchingBackAndForthKeepsTheOverlay() throws {
        let canvas = loadedHost()
        let preference = FakeRenderingPreference(choice: .cpu)
        let watch = canvas.follow(preference, device: MTLCreateSystemDefaultDevice(), presenter: ClearingMetalPresenter())
        defer { watch.cancel() }
        #expect(canvas.metalLayer == nil)
        for _ in 0..<2 {
            preference.set(.gpu)
            let metal = try #require(canvas.metalLayer)
            #expect(metal.colorspace != nil)
            #expect(canvas.container.isHidden)
            #expect(overlayOnTop(canvas))
            preference.set(.cpu)
            #expect(canvas.metalLayer == nil)
            #expect(!canvas.container.isHidden)
            #expect(overlayOnTop(canvas))
        }
        let metalLayers = canvas.layer?.sublayers?.filter { $0 is CAMetalLayer }.count
        #expect(metalLayers == 0)
    }
}

/// Whether this machine's Metal layers hand out drawables off screen (a CI VM's may not); the
/// presenter tests that need one return early when not.
@MainActor func drawablesWork() -> Bool {
    let probe = CAMetalLayer()
    probe.device = MTLCreateSystemDefaultDevice()
    probe.drawableSize = CGSize(width: 8, height: 8)
    return probe.device != nil && probe.nextDrawable() != nil
}

/// Counts the tiles each `show` hands it.
@MainActor private final class RecordingPresenter: MetalPresenting {
    var shown: [Int] = []
    func present(_ drawable: any CAMetalDrawable, on layer: CAMetalLayer) {}
    func show(_ tiles: [CanvasTile], documentSize: CGSize) { shown.append(tiles.count) }
}

/// The fake document's first tile again, as a brush event's one dirty tile.
private struct OneTile: CanvasContentProviding {
    let documentSize = FakeCanvasContent().documentSize
    func tiles(dirtyOnly: Bool) -> [CanvasTile] { Array(FakeCanvasContent().tiles(dirtyOnly: true).prefix(1)) }
}

/// An 8K (7680 x 4320) document with no tiles yet, as Photo's is when it opens.
private struct EightK: CanvasContentProviding {
    let documentSize = CGSize(width: 7680, height: 4320)
    func tiles(dirtyOnly: Bool) -> [CanvasTile] { [] }
}

/// A 960 x 600 host showing the fake document's 20 tiles, laid out.
@MainActor private func loadedHost() -> CanvasHostView {
    let canvas = CanvasHostView(frame: CGRect(x: 0, y: 0, width: 960, height: 600))
    canvas.show(FakeCanvasContent())
    canvas.layoutSubtreeIfNeeded()
    return canvas
}

/// The overlay is still the host layer's top sublayer, named as the journeys expect.
@MainActor private func overlayOnTop(_ canvas: CanvasHostView) -> Bool {
    canvas.overlay.superlayer === canvas.layer && canvas.layer?.sublayers?.last === canvas.overlay
        && canvas.overlay.name == RenderingControlID.overlay
}
