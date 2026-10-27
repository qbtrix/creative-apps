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
// are not the live ones. The dispatcher route keeps its own base per region in the same `PhotoCompositeCache`
// (`composite`): the layers the stack still shares, from the bottom, with the last render, so a Move,
// transform, opacity or visibility step composites the changed layer and the ones above it, not a hundred
// layers. Linux-safe.
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
        // The base ends under the lowest adjustment layer, and under a drag frame's draft (drawn through its matrix).
        let split = shown.firstIndex { layer in
            if case .adjustment = layer.kind { return true }
            return layer.id == liveDraftLayer
        } ?? shown.endIndex
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
                if layer.id == liveDraftLayer, let draft = transformDraft, let tiled = pixels[layer.id] {
                    try compositeDraft(draft, tiled, of: layer, onto: &picture, at: work, on: dispatcher)
                } else {
                    try dispatcher.composite(residentSteps([layer], in: work, resident: resident), onto: &picture)
                }
            }
        }
        if work != rect {
            picture = try sharpened(picture, keep: base)
        }
        try write(picture, rect, stack.display)
    }
}

/// Each region's composite of the layers under the ones being edited, kept between renders while those layers
/// are unchanged, so a step composites what changed and what lies above it, never the whole stack. The live
/// route keeps its base (the pixel layers under the lowest adjustment layer) as GPU surfaces it owns
/// (`surface`); the dispatcher route keeps the layers the stack still shares, from the bottom, with the last
/// render, as a surface on a GPU backend or as the pixels themselves on the CPU, whose backend lives one render,
/// and hands back a copy to draw on (`composite`). A region is kept under its layers' key (the layer, its pixels
/// and its mask, whose comparison is quick on shared storage); the live route's regions all share one key, and
/// keeping one under a new key releases every region kept under another. Thread-safe: bands and tiles render in
/// parallel, and a kept surface is copied or released only under the lock.
/// ponytail: the kept regions are one picture's worth of memory (about 265 MB at 8K); cap them if a profile shows it.
public final class PhotoCompositeCache: Sendable {
    struct LayerKey: Equatable, Sendable {
        let layer: PhotoLayer
        let pixels: TiledPixels?
        let mask: TiledPixels?
        /// The draft a drag frame draws this layer through; nil for a layer drawn as it is.
        var draft: TransformDraft? = nil
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
        /// The layers composited into `surface`, bottom first, and the unsharp pass kept in it, if any.
        let key: Key
        /// The whole stack at the render that made it (`composite` picks the next base from it).
        var stack: [LayerKey] = []
        let surface: RenderSurface
        let backend: any RenderBackend
    }

    /// The CPU route's regions: its backend lives one render, so the pixels are kept, not a surface.
    private struct Pixels: Sendable {
        let key: [LayerKey], stack: [LayerKey]
        let pixels: PixelBuffer
    }

    private let entries = Mutex<[PixelRect: Entry]>([:])
    private let buffers = Mutex<[PixelRect: Pixels]>([:])
    private let makes = Mutex(0)

    public init() {}

    /// Regions kept.
    public var count: Int { entries.withLock { $0.count } + buffers.withLock { $0.count } }
    /// Composites made so far (a region not kept, or kept under other layers).
    public var made: Int { makes.withLock { $0 } }

    static func key(_ layers: [PhotoLayer], pixels: [PhotoLayer.ID: TiledPixels],
                    masks: [PhotoLayer.ID: TiledPixels] = [:], draft: TransformDraft? = nil) -> [LayerKey] {
        layers.map { LayerKey(layer: $0, pixels: pixels[$0.id], mask: masks[$0.id], draft: $0.id == draft?.layerID ? draft : nil) }
    }

    /// `rect`'s composite of the first `laid` layers of `stack`, a surface the caller lays the rest on and
    /// releases: the kept base copied while `stack` still starts with its layers, else a new one made by
    /// `make(laid)` and kept, where `laid` is how many layers `stack` shares, from the bottom, with the last
    /// render's (all of them for the first). So the layer a gesture changes step after step, and the ones above
    /// it, are all that composite again, and a step that changes none of them composites nothing. A region is
    /// kept as a surface only when its composite lives on the GPU (`preferred`, healthy); while the GPU's kernels
    /// still compile, or on the CPU route, the composite lands on the CPU backend, which lives one render, so the
    /// pixels are kept instead, and a lookup reads both.
    func composite(_ rect: PixelRect, stack: [LayerKey], on dispatcher: RenderDispatcher,
                   make: (Int) throws -> RenderSurface) throws -> (surface: RenderSurface, laid: Int) {
        let gpu = dispatcher.preferred.flatMap { $0.isHealthy ? $0 : nil }
        let copy = { (kept: RenderSurface) in try dispatcher.cropped(kept, x: 0, y: 0, width: rect.width, height: rect.height) }
        if let gpu {
            let hit: (RenderSurface, Int)? = try entries.withLock { entries in
                guard let held = entries[rect], held.backend.name == gpu.name, held.key.sharpen.isEmpty,
                      stack.starts(with: held.key.layers) else { return nil }
                return (try copy(held.surface), held.key.layers.count)
            }
            if let hit {
                PhotoRenderCount.base(made: false)
                return hit
            }
        }
        if let held = buffers.withLock({ $0[rect] }), stack.starts(with: held.key) {
            PhotoRenderCount.base(made: false)
            return (try dispatcher.surface(held.pixels), held.key.count)
        }
        let last = entries.withLock { $0[rect]?.stack } ?? buffers.withLock { $0[rect]?.stack }
        let laid = Self.shared(stack, with: last)
        let made = try make(laid)
        makes.withLock { $0 += 1 }
        PhotoRenderCount.base(made: true)
        if let gpu, made.backend == gpu.name {
            return try entries.withLock { entries in
                if let old = entries[rect] { old.backend.release(old.surface) }
                entries[rect] = Entry(key: Key(layers: Array(stack[..<laid])), stack: stack, surface: made, backend: gpu)
                return (try copy(made), laid)
            }
        }
        let pixels = try dispatcher.read(made)  // render-contract: allow the CPU backend's own buffer, no GPU readback
        buffers.withLock { $0[rect] = Pixels(key: Array(stack[..<laid]), stack: stack, pixels: pixels) }
        return (made, laid)
    }

    /// How many layers `stack` shares, from the bottom, with `last`; all of them with no last render.
    static func shared(_ stack: [LayerKey], with last: [LayerKey]?) -> Int {
        guard let last else { return stack.count }
        return zip(stack, last).prefix { $0 == $1 }.count
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
        buffers.withLock { $0 = [:] }
        let all = entries.withLock { entries -> [Entry] in
            defer { entries = [:] }
            return Array(entries.values)
        }
        for entry in all { entry.backend.release(entry.surface) }
    }

    deinit { removeAll() }
}
