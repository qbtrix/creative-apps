// PhotoLiveTone.swift: the live route for adjustments and adjustment layers on the GPU. While a colour or tone
// slider drags, or anything else redraws, a region must cost GPU passes over resident pixels, never a readback
// or a CPU pixel loop. On the resident route with a target that runs a tone program (`PhotoDisplayTarget
// .writeToned`, the app's Metal `display_tone`) and a backend that runs one over a surface (CoreRender's
// `ToneRendering`), a region is drawn from `liveStack()`: the pixel layers under the lowest visible adjustment
// layer, composited from resident tiles and kept per region in `PhotoCompositeCache` until one of them changes;
// then the layers above it bottom-up, an adjustment layer as one program pass (composited back onto the picture
// with its blend mode and opacity when those aren't normal and 1) and a pixel layer as one batched composite;
// then the adjustment layers at the top (normal, opacity 1) and the image's adjustments, folded into the one
// program the target writes the picture through. A whole-image slider step is that write over the cached
// composite: no compositing, no upload, no readback. The program is SuiteImaging's step list, the one
// `applied(to:)` runs (exposure, levels with its output, curves in sRGB), skipped at identity, and Hue/Saturation is
// Photo's own colour matrix and lightness (HueSaturation.swift) as a ToneProgram matrix operation, so the GPU
// picture matches the CPU's. With the tone section's Sharpen on, the unsharp pass runs where export runs it, over
// every layer and before the image's adjustments: no adjustment layer folds into the write, and the region
// draws over a margin of the unsharp's reach, then is sharpened and cropped. With no adjustment layer the
// sharpened base is what the cache keeps, so a slider step still draws over kept pixels. `liveStack` is nil,
// and the region takes the dispatcher route, when the image's Blur is on (it reads neighbours), when a visible
// layer has an enabled mask, when a layer's opacity is outside 0...1, or when the services' adjustment layers
// are not the live ones. Linux-safe.
import CoreRaster
import CoreRender
import Synchronization

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

/// How a region draws on the live route (PhotoLiveTone.swift).
struct PhotoLiveStack: Sendable {
    enum Step: Sendable {
        case pixels(PhotoLayer)
        case adjustment(PhotoLayer, ToneProgram)
    }

    /// The pixel layers under the lowest visible adjustment layer, bottom first: the cached composite.
    let base: [PhotoLayer]
    /// The visible layers above the base, bottom first, less the top ones folded into `display`.
    let steps: [Step]
    /// The top adjustment layers' operations, lowest first, then the image's.
    let display: ToneProgram
    /// The tone section's unsharp pass, run over the layers before `display`; nil when Sharpen is off.
    var unsharp: (amount: Double, sigma: Double, threshold: Double)? = nil

    /// Pixels a region reads beyond itself for the unsharp pass, ceil(3 sigma); 0 when Sharpen is off.
    var margin: Int { unsharp.map { Int((3 * $0.sigma).rounded(.up)) } ?? 0 }
}

extension PhotoWorkspace {
    /// The live route's plan for this stack; nil when it needs the dispatcher route (see the header).
    // render-contract: gpu-route
    func liveStack() -> PhotoLiveStack? {
        guard services.adjustmentLayers is LiveAdjustmentLayering, let image = adjustments.toneOperations else { return nil }  // render-contract: cpu-op live-blur
        let shown = layers.reversed().filter { $0.isVisible && $0.opacity > 0 }  // bottom first
        guard shown.allSatisfy({ (0...1).contains(Float($0.opacity)) }) else { return nil }  // render-contract: cpu-op layer-opacity-range
        var operations: [PhotoLayer.ID: [ToneProgram.Operation]] = [:]
        for layer in shown {
            guard shownMask(of: layer) == nil else { return nil }  // render-contract: cpu-op masked-layer
            guard case .adjustment(var settings) = layer.kind else { continue }
            settings.apply(.setEnabled(.blur, false))  // a layer never blurs (LiveAdjustmentLayering)
            operations[layer.id] = settings.toneOperations ?? []
        }
        let split = shown.firstIndex { if case .adjustment = $0.kind { true } else { false } } ?? shown.endIndex
        var above = Array(shown[split...])
        var folded: [ToneProgram.Operation] = []
        let unsharp = adjustments.unsharp
        while unsharp == nil, let top = above.last, let ops = operations[top.id], top.opacity == 1, top.blendMode == .normal {
            folded = ops + folded
            above.removeLast()
        }
        do {
            let steps = try above.map { layer -> PhotoLiveStack.Step in
                guard let ops = operations[layer.id] else { return .pixels(layer) }
                return .adjustment(layer, try ToneProgram(operations: ops))
            }
            return PhotoLiveStack(
                base: Array(shown[..<split]), steps: steps, display: try ToneProgram(operations: folded + image), unsharp: unsharp)
        } catch {
            return nil  // render-contract: cpu-op tone-program-op (the dispatcher route draws it)
        }
    }

    /// `rect` of the canvas on the live route, written through `writeToned`: the cached base, then `stack`'s
    /// steps on GPU passes, then its unsharp pass, then the display program in the write.
    func liveRegion(
        _ rect: PixelRect, stack: PhotoLiveStack, on dispatcher: RenderDispatcher, resident: ResidentSurfaces,
        tone: any ToneRendering, cache: PhotoCompositeCache,
        write: (_ surface: RenderSurface, _ rect: PixelRect, _ tone: ToneProgram) throws -> Void
    ) throws {
        guard let canvas, let outer = rect.expanded(by: stack.margin).intersection(canvas.rect) else {
            throw RasterError.invalid("region \(rect) is outside the image")
        }
        /// `picture` (of `outer`) sharpened and cropped to `rect`; releases `picture` unless it is `keep`.
        func sharpened(_ picture: RenderSurface, keep: RenderSurface?) throws -> RenderSurface {
            guard let s = stack.unsharp else { return picture }
            defer { if picture != keep { dispatcher.release(picture) } }
            let whole = try dispatcher.unsharpMask(picture, amount: s.amount, sigma: s.sigma, threshold: s.threshold)
            defer { dispatcher.release(whole) }
            return try dispatcher.cropped(whole, x: rect.x - outer.x, y: rect.y - outer.y, width: rect.width, height: rect.height)
        }
        let layers = PhotoCompositeCache.key(stack.base, pixels: pixels)
        // With no steps the cache keeps the sharpened region; with steps it keeps the padded composite they run on.
        let sharpenBase = stack.steps.isEmpty && stack.unsharp != nil
        let work = stack.unsharp == nil || sharpenBase ? rect : outer
        let key = PhotoCompositeCache.Key(layers: layers, unsharp: sharpenBase ? stack.unsharp : nil)
        let base = try cache.surface(work, key: key, on: tone) {
            let composite = try residentComposited(sharpenBase ? outer : work, layers: stack.base, on: dispatcher, resident: resident)
            return sharpenBase ? try sharpened(composite, keep: nil) : composite
        }
        var picture = base
        defer { if picture != base { dispatcher.release(picture) } }
        /// The picture as a surface of this region's own, never the cached base.
        func owned() throws {
            if picture == base { picture = try tone.adjusted(base, tone: ToneProgram([])) }
        }
        PhotoRenderCount.layers(stack.steps.count)
        for step in stack.steps {
            switch step {
            case .adjustment(let layer, let program):
                let adjusted = try tone.adjusted(picture, tone: program)
                if layer.opacity == 1, layer.blendMode == .normal {
                    if picture != base { dispatcher.release(picture) }
                    picture = adjusted
                } else {
                    defer { dispatcher.release(adjusted) }
                    try owned()
                    try dispatcher.composite(adjusted, onto: &picture, x: 0, y: 0, mode: layer.blendMode, opacity: Float(layer.opacity))
                }
            case .pixels(let layer):
                try owned()
                try dispatcher.composite(residentSteps([layer], in: work, resident: resident), onto: &picture)
            }
        }
        if work != rect {
            picture = try sharpened(picture, keep: base)
        }
        try write(picture, rect, stack.display)
    }
}

/// Each region's composite of the live route's base layers, kept on the GPU between renders while those layers
/// are unchanged, so a slider step re-encodes it instead of compositing again. A region is kept under the
/// layers' key (id, blend, opacity, offset and pixels, whose comparison is quick on shared storage); keeping one
/// under a new key releases every region kept under another. Thread-safe: bands render in parallel.
public final class PhotoCompositeCache: Sendable {
    struct LayerKey: Equatable, Sendable {
        let id: PhotoLayer.ID
        let blendMode: BlendMode
        let opacity: Double
        let offsetX: Int, offsetY: Int
        let pixels: TiledPixels?
    }

    /// The layers a region composites, and the unsharp pass it keeps sharpened, if any.
    struct Key: Equatable, Sendable {
        let layers: [LayerKey]
        let sharpen: [Double]

        init(layers: [LayerKey], unsharp: (amount: Double, sigma: Double, threshold: Double)? = nil) {
            self.layers = layers
            sharpen = unsharp.map { [$0.amount, $0.sigma, $0.threshold] } ?? []
        }
    }

    private struct Entry: Sendable {
        let key: Key
        let surface: RenderSurface
        let backend: any RenderBackend
    }

    private let entries = Mutex<[PixelRect: Entry]>([:])
    private let makes = Mutex(0)

    public init() {}

    /// Regions kept.
    public var count: Int { entries.withLock { $0.count } }
    /// Composites made so far (a region not kept, or kept under other layers).
    public var made: Int { makes.withLock { $0 } }

    static func key(_ layers: [PhotoLayer], pixels: [PhotoLayer.ID: TiledPixels]) -> [LayerKey] {
        layers.map {
            LayerKey(id: $0.id, blendMode: $0.blendMode, opacity: $0.opacity, offsetX: $0.offsetX, offsetY: $0.offsetY,
                     pixels: pixels[$0.id])
        }
    }

    /// The kept composite of `rect` under `key` on `backend`, else `make()`'s, kept. The cache owns it: the
    /// caller never releases it.
    func surface(_ rect: PixelRect, key: Key, on backend: any RenderBackend,
                 make: () throws -> RenderSurface) throws -> RenderSurface {
        if let held = entries.withLock({ $0[rect] }), held.key == key, held.backend.name == backend.name { return held.surface }
        let made = try make()
        makes.withLock { $0 += 1 }
        let stale: [Entry] = entries.withLock { entries in
            let old = entries.filter { $0.key == rect || $0.value.key != key || $0.value.backend.name != backend.name }
            for rect in old.keys { entries[rect] = nil }
            entries[rect] = Entry(key: key, surface: made, backend: backend)
            return Array(old.values)
        }
        for entry in stale { entry.backend.release(entry.surface) }
        return made
    }

    /// Releases every kept region.
    public func removeAll() {
        let all = entries.withLock { entries -> [Entry] in
            defer { entries = [:] }
            return Array(entries.values)
        }
        for entry in all { entry.backend.release(entry.surface) }
    }

    deinit { removeAll() }
}
