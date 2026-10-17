// CanvasHostView+Metal.swift: the canvas host's GPU path (canvas-host CH-10).
// Under `.gpu` with a Metal device the tile container hides and a
// `CAMetalLayer` (sRGB colour space) takes its place under the overlay; its
// drawable goes to a `MetalPresenting` value (core's display op later, the
// clearing fake now). `.cpu`, `.automatic` (CPU for the beta) or a nil device
// keep the tile layers. The overlay stays on top on both paths. macOS only.
import AppKit
import Combine
import Metal
import QuartzCore
import SwiftUI

/// Fills a host's Metal drawable. The host never draws into it itself.
@MainActor
public protocol MetalPresenting: AnyObject, Sendable {
    func present(_ drawable: any CAMetalDrawable, on layer: CAMetalLayer)
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
    /// The installed Metal layer; nil on the tile path.
    public var metalLayer: CAMetalLayer? {
        layer?.sublayers?.lazy.compactMap { $0 as? CAMetalLayer }.first
    }

    /// Whether `choice` draws on Metal here: only `.gpu` with a device. Automatic draws on CPU for the beta.
    static func drawsOnMetal(_ choice: RenderingChoice, device: (any MTLDevice)?) -> Bool {
        guard choice == .gpu, device != nil else { return false }
        return true
    }

    /// Switches the host to `choice`'s path: a `CAMetalLayer` under the overlay, or the tile layers.
    public func useRendering(_ choice: RenderingChoice, device: (any MTLDevice)?, presenter: any MetalPresenting) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard Self.drawsOnMetal(choice, device: device) else {
            metalLayer?.removeFromSuperlayer()
            container.isHidden = false
            return
        }
        let metal = metalLayer ?? CAMetalLayer()
        metal.device = device
        metal.pixelFormat = .bgra8Unorm
        metal.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        metal.name = RenderingControlID.canvas + ".metal"
        if metal.superlayer == nil { layer?.insertSublayer(metal, below: overlay) }
        container.isHidden = true
        presentMetal(with: presenter)
    }

    /// Sizes the Metal layer to the artboard and hands one drawable to `presenter`; nothing on the tile path.
    public func presentMetal(with presenter: any MetalPresenting) {
        guard let metal = metalLayer else { return }
        let board = artboard
        let scale = window?.backingScaleFactor ?? metal.contentsScale
        metal.frame = board
        metal.contentsScale = scale
        metal.drawableSize = CGSize(width: max(board.width * scale, 1), height: max(board.height * scale, 1))
        guard let drawable = metal.nextDrawable() else { return }
        presenter.present(drawable, on: metal)
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
