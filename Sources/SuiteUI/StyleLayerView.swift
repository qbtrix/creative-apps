// StyleLayerView.swift (layer-styles HY-7): one styled layer on the GPU for any app; StyleLayerRoute keeps one
// StyleLayerGPU per layer id. Off the GPU route `isAvailable` is false and the app draws the layer itself.
import AppKit
import CoreRaster
import SuiteImaging
import SwiftUI

@MainActor @Observable public final class StyleLayerRoute {
    public static let shared = StyleLayerRoute(preference: RenderingPreference(suiteName: RenderingPreference.suiteName))
    @ObservationIgnored let preference: any RenderingPreferenceReading
    @ObservationIgnored private var backend: ImagingGPU.Backend??
    @ObservationIgnored private var layers: [String: StyleLayerGPU] = [:]
    /// True once a GPU write failed; the app then draws its layers itself.
    public private(set) var failed = false
    public init(preference: any RenderingPreferenceReading) { self.preference = preference }
    /// A choice other than CPU, a healthy backend with its pipelines ready, and no failure.
    public var isAvailable: Bool {
        guard preference.choice != .cpu, !failed else { return false }
        if backend == nil { backend = ImagingGPU.systemBackend() }
        guard let gpu = backend ?? nil else { return false }
        return gpu.isHealthy && gpu.isReady
    }
    /// Layer `id`'s GPU drawer, made on first use; nil without a backend.
    public func layer(_ id: String) -> StyleLayerGPU? {
        guard let gpu = backend ?? nil else { return nil }
        let held = layers[id] ?? StyleLayerGPU(gpu)
        layers[id] = held
        return held
    }
    /// Layer `id` with `style` into `view`'s resident texture, `width` x `height`.
    func draw(_ id: String, content: AnyHashable, width: Int, height: Int, style: LayerStyle?,
              pixels: () -> PixelBuffer?, into view: CanvasHostView) {
        view.show(Shown(width: width, height: height))
        do {
            guard let gpu = backend ?? nil, let drawer = layer(id), let presenter = view.metalPresenter as? CanvasTilePresenter,
                  let texture = presenter.residentTexture(on: gpu.device, width: width, height: height)
            else { throw ImagingError.notBuilt("the GPU route isn't available") }
            try drawer.draw(content: content, pixels: { try pixels() ?? PixelBuffer(width: width, height: height) },
                            style: style, scale: 1, into: texture)
            view.show(Shown(width: width, height: height))
        } catch {
            layers[id] = nil
            Task { @MainActor in self.failed = true }  // not during the view update that called this
        }
    }
    /// The layer's size with no tiles: the texture holds the pixels.
    struct Shown: CanvasContentProviding {
        let width: Int, height: Int
        var documentSize: CGSize { CGSize(width: width, height: height) }
        func tiles(dirtyOnly: Bool) -> [CanvasTile] { [] }
    }
}

/// Layer `id` drawn with `style` over its frame by `route`; `content` keys `pixels` (linear premultiplied).
public struct StyleLayerView: View {
    let route: StyleLayerRoute, id: String, content: AnyHashable, width: Int, height: Int, style: LayerStyle?
    let pixels: () -> PixelBuffer?
    public init(route: StyleLayerRoute, id: String, content: AnyHashable, width: Int, height: Int, style: LayerStyle?,
                pixels: @escaping () -> PixelBuffer?) {
        (self.route, self.id, self.content, self.width, self.height, self.style, self.pixels) = (route, id, content, width, height, style, pixels)
    }

    public var body: some View {
        EmbeddedCanvasHost(rendering: route.preference) { view in
            route.draw(id, content: content, width: width, height: height, style: style, pixels: pixels, into: view)
        }
        .allowsHitTesting(false)
    }
}
