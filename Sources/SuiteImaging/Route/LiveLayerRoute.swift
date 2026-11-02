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

/// Each region's composite of the live route's base layers, kept on the GPU between renders while those layers
/// are unchanged, so a slider step re-encodes it instead of compositing again. A region is kept under its layers'
/// keys; keeping one under a new key releases every region kept under another. Thread-safe: bands render in
/// parallel.
public final class LiveCompositeCache<Region: LiveRegion>: Sendable {
    private struct Entry: Sendable {
        let key: any Sendable
        let surface: RenderSurface
        let backend: any RenderBackend

        func holds<Key: Equatable & Sendable>(_ key: Key, on backend: any RenderBackend) -> Bool {
            (self.key as? Key) == key && self.backend.name == backend.name
        }
    }

    private let entries = Mutex<[Region: Entry]>([:])
    private let makes = Mutex(0)

    public init() {}

    /// Regions kept.
    public var count: Int { entries.withLock { $0.count } }
    /// Composites made so far (a region not kept, or kept under other layers).
    public var made: Int { makes.withLock { $0 } }

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
