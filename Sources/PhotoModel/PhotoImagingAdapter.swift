// PhotoImagingAdapter.swift: Photo's side of SuiteImaging's live layer route
// (LiveLayerRoute.swift, suite-imaging IM-8d). On the resident route with a
// target that runs a tone program (`PhotoDisplayTarget.writeToned`, the app's
// Metal `display_tone`) and a backend that runs one over a surface
// (CoreRender's `ToneRendering`), a region is drawn from `liveStack()`: the
// visible layers as `LiveLayer`s, folded by the route under the image's own
// operations. The program is SuiteImaging's step list, the one `applied(to:)`
// runs, and Hue/Saturation is Photo's own colour matrix and lightness
// (HueSaturation.swift) as a ToneProgram matrix operation, so the GPU picture
// matches the CPU's. `liveStack` is nil, and the region takes the dispatcher
// route, when the image's Blur is on (it reads neighbours), when a visible
// layer has an enabled mask (#5216), when a layer's opacity is outside
// 0...1, or when the services' adjustment layers are not the live ones.
// Linux-safe.
import CoreRaster
import CoreRender
import SuiteImaging

extension AdjustmentSettings {
    /// The enabled tone steps that change the image: ImagingProgram's steps as `applied(to:)` runs them, with
    /// Hue/Saturation as Photo's own matrix (`runImaging`); nil while Blur would run.
    var toneOperations: [ToneProgram.Operation]? {
        guard blurMargin == 0 else { return nil }
        return imagingSteps.map { step in
            guard case .hueSaturation = step else { return .adjustment(step) }
            return .matrix(rows: PixelBuffer.colorMatrix(hue: hue, saturation: saturation),
                           lightness: Float(min(max(lightness, -100), 100) / 100))
        }
    }
}

extension PixelRect: LiveRegion {}

/// A visible Photo layer on the live route: its kind, and a key of everything that changes its pixels (id,
/// blend, opacity, offset and pixels, whose comparison is quick on shared storage).
struct PhotoLiveLayer: LiveLayer {
    struct Key: Equatable, Sendable {
        let id: PhotoLayer.ID
        let blendMode: BlendMode
        let opacity: Double
        let offsetX: Int, offsetY: Int
        let pixels: TiledPixels?
    }

    let layer: PhotoLayer
    let liveKind: LiveLayerKind
    let liveKey: Key
    var blendMode: BlendMode { layer.blendMode }
    var opacity: Double { layer.opacity }
}

typealias PhotoLiveStack = LiveLayerStack<PhotoLiveLayer>
/// The canvas routes' kept composites, per tile or band (SuiteImaging's cache); the Curves histogram keeps one too.
public typealias PhotoCompositeCache = LiveCompositeCache<PixelRect>

extension PhotoWorkspace {
    /// The live route's plan for this stack; nil when it needs the dispatcher route (see the header).
    // render-contract: gpu-route
    func liveStack() -> PhotoLiveStack? {
        guard services.adjustmentLayers is LiveAdjustmentLayering, let image = adjustments.toneOperations else { return nil }  // render-contract: cpu-op live-blur
        let shown = layers.reversed().filter { $0.isVisible && $0.opacity > 0 }.map { layer in  // bottom first
            var kind = LiveLayerKind.pixels
            if case .adjustment(var settings) = layer.kind {
                settings.apply(.setEnabled(.blur, false))  // a layer never blurs (LiveAdjustmentLayering)
                kind = .adjustment(settings.toneOperations ?? [])
            }
            if shownMask(of: layer) != nil { kind = .unsupported }  // a masked layer runs on CoreRaster (#5216)
            return PhotoLiveLayer(layer: layer, liveKind: kind, liveKey: PhotoLiveLayer.Key(
                id: layer.id, blendMode: layer.blendMode, opacity: layer.opacity, offsetX: layer.offsetX,
                offsetY: layer.offsetY, pixels: pixels[layer.id]))
        }
        return .folding(shown, image: image)
    }

    /// `rect` of the canvas on the live route, written through `writeToned`, its layers' tiles from `resident`.
    func liveRegion(
        _ rect: PixelRect, stack: PhotoLiveStack, on dispatcher: RenderDispatcher, resident: ResidentSurfaces,
        tone: any ToneRendering, cache: LiveCompositeCache<PixelRect>,
        write: (_ surface: RenderSurface, _ rect: PixelRect, _ tone: ToneProgram) throws -> Void
    ) throws {
        PhotoRenderCount.layers(stack.steps.count)
        try stack.draw(rect, on: dispatcher, resident: resident, tone: tone, cache: cache, tiles: { layers, rect, resident in
            PhotoRenderCount.region()  // a base composite, as residentComposited counts one
            PhotoRenderCount.layers(layers.count)
            return try residentSteps(layers.map(\.layer), in: rect, resident: resident)
        }, write: write)
    }
}
