// CanvasHostView+Metal.swift: the canvas host's GPU path (canvas-host CH-10).
// Under `.gpu` or `.automatic` with a Metal device the tile container hides
// and a `CAMetalLayer` (sRGB colour space) takes its place under the lift and the overlay;
// the presenter is handed every tile shown and fills each drawable
// (CanvasTilePresenter live, the clearing fake in tests). `.cpu` or a nil
// device keep the tile layers. On the Metal path the tile layers get no
// contents (a commit would colour-convert every image on the main thread);
// they get them back from the shown images when the path returns to `.cpu`.
// The drawable is the artboard at the backing scale but never more pixels
// than the document has (Core Animation magnifies it, nearest from 2 px per
// pixel, as the tile path does), and it turns with `rotationDegrees`; with no
// artboard (a zero-size host) nothing is presented. A layout
// presents a new drawable only for a new picture or a new drawable size, so a
// pan or a rotation moves the one shown. The overlay stays on top on both
// paths. macOS only.
import AppKit
import Combine
import Metal
import QuartzCore
import SuiteImaging
import SwiftUI

/// Fills a host's Metal drawable. The host never draws into it itself.
@MainActor
public protocol MetalPresenting: AnyObject, Sendable {
    func present(_ drawable: any CAMetalDrawable, on layer: CAMetalLayer)
    /// The tiles the host shows, all of them on a new size or path: what later drawables draw.
    func show(_ tiles: [CanvasTile], documentSize: CGSize)
}

extension MetalPresenting {
    public func show(_ tiles: [CanvasTile], documentSize: CGSize) {}
}

/// The fake presenter: clears each drawable to the artboard colour and counts the frames.
@MainActor
public final class ClearingMetalPresenter: MetalPresenting {
    public private(set) var presented = 0
    private var queue: (any MTLCommandQueue)?

    public init() {}

    public func present(_ drawable: any CAMetalDrawable, on layer: CAMetalLayer) {
        guard let device = layer.device else { return }
        if queue == nil { queue = device.makeCommandQueue() }
        guard let buffer = queue?.makeCommandBuffer() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = Self.artboardClear
        buffer.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
        buffer.present(drawable)
        buffer.commit()
        presented += 1
    }

    /// `SuiteColor.artboard` in sRGB components; a missing component reads as 1.
    static var artboardClear: MTLClearColor {
        let color = SuiteColor.artboard.resolve(in: EnvironmentValues()).cgColor
        let srgb = CGColorSpace(name: CGColorSpace.sRGB).flatMap {
            color.converted(to: $0, intent: .defaultIntent, options: nil)
        }
        let parts = srgb?.components ?? []
        let part = { (index: Int) in Double(index < parts.count ? parts[index] : 1) }
        return MTLClearColorMake(part(0), part(1), part(2), part(3))
    }
}

/// The device and presenter a followed preference switches with, held for the observer.
@MainActor
final class MetalRoute {
    let device: (any MTLDevice)?
    let presenter: any MetalPresenting
    init(device: (any MTLDevice)?, presenter: any MetalPresenting) {
        self.device = device
        self.presenter = presenter
    }
}

extension CanvasHostView {
    /// The presenter filling the Metal layer; nil on the tile path.
    public var metalPresenter: (any MetalPresenting)? { presenter }

    /// Where a resident render on `backend` writes a `width` x `height` picture: the live presenter's document
    /// texture, so the app names no texture type. Nil off the Metal path or with another presenter.
    public func residentTarget(on backend: ImagingGPU.Backend, width: Int, height: Int) -> ImagingGPU.Target? {
        guard let presenter = presenter as? CanvasTilePresenter,
            let texture = presenter.residentTexture(on: backend.device, width: width, height: height)
        else { return nil }
        return ImagingGPU.Target(texture, on: backend)
    }

    /// The installed Metal layer; nil on the tile path.
    public var metalLayer: CAMetalLayer? {
        layer?.sublayers?.lazy.compactMap { $0 as? CAMetalLayer }.first
    }

    /// Whether `choice` draws on Metal here: `.gpu` or `.automatic`, with a device.
    static func drawsOnMetal(_ choice: RenderingChoice, device: (any MTLDevice)?) -> Bool {
        choice != .cpu && device != nil
    }

    /// Switches the host to `choice`'s path: a `CAMetalLayer` under the overlay, or the tile layers.
    public func useRendering(_ choice: RenderingChoice, device: (any MTLDevice)?, presenter: any MetalPresenting) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard Self.drawsOnMetal(choice, device: device) else {
            metalLayer?.removeFromSuperlayer()
            (self.presenter, container.isHidden) = (nil, false)
            place(shown())  // the Metal path left the tile layers without contents
            return
        }
        let metal = metalLayer ?? CAMetalLayer()
        metal.device = device
        metal.pixelFormat = .bgra8Unorm
        metal.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        metal.name = RenderingControlID.canvas + ".metal"
        // The presenter scales into the drawable with a compute kernel, which writes the texture.
        metal.framebufferOnly = false
        // Not opaque (its default): a clear pixel shows the viewport's checkerboard, as a tile layer's does.
        metal.isOpaque = false
        if metal.superlayer == nil { layer?.insertSublayer(metal, below: liftSpace) }
        container.isHidden = true
        self.presenter = presenter
        presenter.show(shown(), documentSize: documentSize)
        pictureChanged = true
        presentMetal(with: presenter)
    }

    /// Sizes the Metal layer to the artboard and hands one drawable to `presenter`; nothing on the tile path.
    public func presentMetal(with presenter: any MetalPresenting) {
        guard let metal = metalLayer else { return }
        let board = artboard
        let scale = window?.backingScaleFactor ?? metal.contentsScale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        metal.setAffineTransform(.identity)
        metal.frame = board
        metal.setAffineTransform(CGAffineTransform(rotationAngle: -rotationDegrees * .pi / 180))
        metal.contentsScale = scale
        metal.magnificationFilter = documentSize.width > 0 && board.width / documentSize.width >= 2 ? .nearest : .linear
        CATransaction.commit()
        // No artboard yet (a window's first layout is at zero size): nothing to show, so no drawable.
        guard !board.isEmpty else { return }
        let size = Self.drawableSize(board: board.size, scale: scale, document: documentSize)
        // A pan, a rotation or a layout that keeps the picture and the drawable's size needs no new drawable:
        // Core Animation moves and scales the one shown.
        guard pictureChanged || presentedSize != size else { return }
        metal.drawableSize = size
        guard let drawable = metal.nextDrawable() else { return }
        (pictureChanged, presentedSize) = (false, size)
        presenter.present(drawable, on: metal)
    }

    /// The artboard in pixels at `scale`, never more than the document's pixels on either side
    /// (with no document, the artboard alone), and at least 1 x 1.
    nonisolated static func drawableSize(board: CGSize, scale: CGFloat, document: CGSize) -> CGSize {
        let cap = { (side: CGFloat, limit: CGFloat) in max(limit > 0 ? min(side, limit) : side, 1) }
        return CGSize(width: cap(board.width * scale, document.width), height: cap(board.height * scale, document.height))
    }

    /// Follows `preference` onto Metal (a CanvasTilePresenter on the system GPU) or the tile layers
    /// for the view's life.
    public func followRendering(_ preference: any RenderingPreferenceReading) {
        renderingWatch = follow(preference, device: MTLCreateSystemDefaultDevice(), presenter: CanvasTilePresenter())
    }

    /// Applies `preference`'s choice now and on every change until the result is cancelled.
    public func follow(_ preference: any RenderingPreferenceReading, device: (any MTLDevice)?,
                       presenter: any MetalPresenting) -> AnyCancellable {
        let route = MetalRoute(device: device, presenter: presenter)
        useRendering(preference.choice, device: route.device, presenter: route.presenter)
        return preference.observe { [weak self] choice in
            self?.useRendering(choice, device: route.device, presenter: route.presenter)
        }
    }
}
