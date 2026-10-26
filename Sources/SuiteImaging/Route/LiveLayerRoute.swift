// LiveLayerRoute.swift: a layered picture's live route on the GPU (suite-imaging
// IM-8d, slice IM-photo, lifted from Photo's PhotoLiveTone, photo #3144). While
// a tone slider drags, or anything else redraws, a region costs GPU passes over
// resident pixels, never a readback or a CPU pixel loop. `LiveLayerStack.folding`
// plans the stack: the pixel layers under the lowest adjustment layer are the
// base, composited from resident tiles and kept per region in
// `LiveCompositeCache` until one of them changes; the layers above it are steps
// run bottom-up, an adjustment layer as one program pass (composited back onto
// the picture with its blend mode and opacity when those aren't normal and 1)
// and a pixel layer as one batched composite; the adjustment layers at the top
// (normal, opacity 1) and then the image's own operations fold into the one
// program the target writes the picture through. A whole-image slider step is
// that write over the cached composite: no compositing, no upload, no readback.
// An app's layer adapts to `LiveLayer` (Photo's PhotoImagingAdapter), so this
// file never sees an app's model. Linux-safe: generic over CoreRender's
// ToneRendering, ResidentSurfaces and RenderDispatcher, writing through a closure.
import CoreRaster
import CoreRender
import Synchronization

/// What the live route draws a layer as.
public enum LiveLayerKind: Equatable, Sendable {
    /// Pixels, composited with the layer's blend mode and opacity.
    case pixels
    /// An adjustment layer: its tone operations, run over everything under it.
    case adjustment([ToneProgram.Operation])
    /// A layer the route can't draw (a masked layer, say): the whole stack takes the dispatcher route.
    case unsupported
}

/// A region of the picture the live route draws (Photo's PixelRect, say): the cache keeps one composite per region.
public protocol LiveRegion: Hashable, Sendable {
    var width: Int { get }
    var height: Int { get }
}

/// One visible layer as the live route sees it.
public protocol LiveLayer: Sendable {
    /// Everything that changes the layer's pixels on the canvas: a cached base is kept under its layers' keys.
    associatedtype Key: Equatable & Sendable
    var liveKind: LiveLayerKind { get }
    var blendMode: BlendMode { get }
    var opacity: Double { get }
    var liveKey: Key { get }
}

/// How a region draws on the live route (LiveLayerRoute.swift).
public struct LiveLayerStack<Layer: LiveLayer>: Sendable {
    public enum Step: Sendable {
        case pixels(Layer)
        case adjustment(Layer, ToneProgram)
    }

    /// The pixel layers under the lowest adjustment layer, bottom first: the cached composite.
    public let base: [Layer]
    /// The layers above the base, bottom first, less the top ones folded into `display`.
    public let steps: [Step]
    /// The top adjustment layers' operations, lowest first, then the image's.
    public let display: ToneProgram

    /// The plan for `shown` (the visible layers, bottom first) under the image's `image` operations; nil when it
    /// needs the dispatcher route: an opacity outside 0...1, an unsupported layer, or an operation no program runs.
    // render-contract: gpu-route
    public static func folding(_ shown: [Layer], image: [ToneProgram.Operation]) -> Self? {
        guard shown.allSatisfy({ (0...1).contains(Float($0.opacity)) }) else { return nil }  // render-contract: cpu-op layer-opacity-range
        guard !shown.contains(where: { $0.liveKind == .unsupported }) else { return nil }  // render-contract: cpu-op masked-layer
        let split = shown.firstIndex { if case .adjustment = $0.liveKind { true } else { false } } ?? shown.endIndex
        var above = Array(shown[split...])
        var folded: [ToneProgram.Operation] = []
        while let top = above.last, case .adjustment(let ops) = top.liveKind, top.opacity == 1, top.blendMode == .normal {
            folded = ops + folded
            above.removeLast()
        }
        do {
            let steps = try above.map { layer -> Step in
                guard case .adjustment(let ops) = layer.liveKind else { return .pixels(layer) }
                return .adjustment(layer, try ToneProgram(operations: ops))
            }
            return Self(base: Array(shown[..<split]), steps: steps, display: try ToneProgram(operations: folded + image))
        } catch {
            return nil  // render-contract: cpu-op tone-program-op (the dispatcher route draws it)
        }
    }

    /// `rect` of the picture on the live route, written through `write`: the cached base, then the steps on GPU
    /// passes, then the display program in the write. `tiles` gives layers' resident tiles under a region as
    /// composite steps onto a surface of it.
    public func draw<Region: LiveRegion>(
        _ rect: Region, on dispatcher: RenderDispatcher, resident: ResidentSurfaces, tone: any ToneRendering,
        cache: LiveCompositeCache<Region>,
        tiles: (_ layers: [Layer], _ rect: Region, _ resident: ResidentSurfaces) throws -> [CompositeStep],
        write: (_ surface: RenderSurface, _ rect: Region, _ tone: ToneProgram) throws -> Void
    ) throws {
        let base = try cache.surface(rect, key: self.base.map(\.liveKey), on: tone) {
            let steps = try tiles(self.base, rect, resident)
            var picture = try dispatcher.blank(width: rect.width, height: rect.height)
            do {
                try dispatcher.composite(steps, onto: &picture)
            } catch {
                dispatcher.release(picture)
                throw error
            }
            return picture
        }
        var picture = base
        defer { if picture != base { dispatcher.release(picture) } }
        /// The picture as a surface of this region's own, never the cached base.
        func owned() throws {
            if picture == base { picture = try tone.adjusted(base, tone: ToneProgram([])) }
        }
        for step in steps {
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
                try dispatcher.composite(tiles([layer], rect, resident), onto: &picture)
            }
        }
        try write(picture, rect, display)
    }
}

/// Each region's composite of the layers under the ones being edited, kept between renders while those layers
/// are unchanged, so a step composites what changed and what lies above it, never the whole stack. The live
/// route keeps its base (the pixel layers under the lowest adjustment layer) as GPU surfaces the cache owns
/// (`surface`); an app's dispatcher route keeps the layers its stack still shares, from the bottom, with the
/// last render, as a surface on a GPU backend or as the pixels themselves on the CPU, whose backend lives one
/// render, and gets a copy to draw on (`composite`). A region is kept under its layers' keys; the live route's
/// regions all share one key, and keeping one under a new key releases every region kept under another.
/// Thread-safe: bands and tiles render in parallel, and a kept surface is copied or released only under the lock.
/// ponytail: the kept regions are one picture's worth of memory (about 265 MB at 8K); cap them if a profile shows it.
public final class LiveCompositeCache<Region: LiveRegion>: Sendable {
    private struct Entry: Sendable {
        /// The layers composited into `surface`, bottom first.
        let key: any Sendable
        /// The whole stack at the render that made it (`composite` picks the next base from it).
        var stack: (any Sendable)?
        let surface: RenderSurface
        let backend: any RenderBackend

        func holds<Key: Equatable & Sendable>(_ key: Key, on backend: any RenderBackend) -> Bool {
            (self.key as? Key) == key && self.backend.name == backend.name
        }
    }

    /// The CPU route's regions: its backend lives one render, so the pixels are kept, not a surface.
    private struct Pixels: Sendable {
        let key: any Sendable, stack: any Sendable
        let pixels: PixelBuffer
    }

    private let entries = Mutex<[Region: Entry]>([:])
    private let buffers = Mutex<[Region: Pixels]>([:])
    private let makes = Mutex(0)

    public init() {}

    /// Regions kept.
    public var count: Int { entries.withLock { $0.count } + buffers.withLock { $0.count } }
    /// Composites made so far (a region not kept, or kept under other layers).
    public var made: Int { makes.withLock { $0 } }

    /// `rect`'s composite of the first `laid` layers of `stack`, a surface the caller lays the rest on and
    /// releases: the kept base copied while `stack` still starts with its layers (`made` false), else a new one
    /// made by `make(laid)` and kept, where `laid` is how many layers `stack` shares, from the bottom, with the
    /// last render's (all of them for the first). So the layer a gesture changes step after step, and the ones
    /// above it, are all that composite again, and a step that changes none of them composites nothing. A region
    /// is kept as a surface only when its composite lives on the GPU (`preferred`, healthy); while the GPU's
    /// kernels still compile, or on the CPU route, the composite lands on the CPU backend, which lives one
    /// render, so the pixels are kept instead, and a lookup reads both.
    public func composite<Key: Equatable & Sendable>(
        _ rect: Region, stack: [Key], on dispatcher: RenderDispatcher, make: (Int) throws -> RenderSurface
    ) throws -> (surface: RenderSurface, laid: Int, made: Bool) {
        let gpu = dispatcher.preferred.flatMap { $0.isHealthy ? $0 : nil }
        let copy = { (kept: RenderSurface) in try dispatcher.cropped(kept, x: 0, y: 0, width: rect.width, height: rect.height) }
        if let gpu {
            let hit: (RenderSurface, Int)? = try entries.withLock { entries in
                guard let held = entries[rect], held.backend.name == gpu.name, let key = held.key as? [Key],
                    stack.starts(with: key) else { return nil }
                return (try copy(held.surface), key.count)
            }
            if let hit { return (hit.0, hit.1, false) }
        }
        if let held = buffers.withLock({ $0[rect] }), let key = held.key as? [Key], stack.starts(with: key) {
            return (try dispatcher.surface(held.pixels), key.count, false)
        }
        let last = (entries.withLock { $0[rect]?.stack } ?? buffers.withLock { $0[rect]?.stack }) as? [Key]
        let laid = Self.shared(stack, with: last)
        let made = try make(laid)
        makes.withLock { $0 += 1 }
        if let gpu, made.backend == gpu.name {
            return try entries.withLock { entries in
                if let old = entries[rect] { old.backend.release(old.surface) }
                entries[rect] = Entry(key: Array(stack[..<laid]), stack: stack, surface: made, backend: gpu)
                return (try copy(made), laid, true)
            }
        }
        let pixels = try dispatcher.read(made)  // render-contract: allow the CPU backend's own buffer, no GPU readback
        buffers.withLock { $0[rect] = Pixels(key: Array(stack[..<laid]), stack: stack, pixels: pixels) }
        return (made, laid, true)
    }

    /// How many layers `stack` shares, from the bottom, with `last`; all of them with no last render.
    static func shared<Key: Equatable>(_ stack: [Key], with last: [Key]?) -> Int {
        guard let last else { return stack.count }
        return zip(stack, last).prefix { $0 == $1 }.count
    }

    /// The kept composite of `rect` under `key` on `backend`, else `make()`'s, kept. The cache owns it: the
    /// caller never releases it.
    public func surface<Key: Equatable & Sendable>(
        _ rect: Region, key: Key, on backend: any RenderBackend, make: () throws -> RenderSurface
    ) throws -> RenderSurface {
        if let held = entries.withLock({ $0[rect] }), held.holds(key, on: backend) { return held.surface }
        let made = try make()
        makes.withLock { $0 += 1 }
        let stale: [Entry] = entries.withLock { entries in
            let old = entries.filter { $0.key == rect || !$0.value.holds(key, on: backend) }
            for gone in old.keys { entries[gone] = nil }
            entries[rect] = Entry(key: key, stack: nil, surface: made, backend: backend)
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
