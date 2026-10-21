// PhotoRenderRoute.swift: where the canvas picture is drawn (render-backend
// adoption R1). A route names the GPU backend to prefer, or none for the CPU;
// each render makes a CoreRender RenderDispatcher from it with a CPUBackend of
// its own, since one CPU backend runs its composites one at a time and the CPU
// route renders tiles in parallel. Through the dispatcher a region of the
// canvas is the visible layers composited bottom-up, then the adjustments,
// then display bytes: a pixel layer's tiles under the region are `composite`
// with its blend mode and opacity (only each tile's painted part goes up, and
// an opaque normal tile that covers the region replaces it, PhotoLayerComposite's
// two shortcuts); exposure, levels and curves are `adjusted` with the same
// sRGB encoding, blur is `gaussianBlur`, and the bytes come from `display`.
// An adjustment layer and Hue/Saturation have no RenderOp, so they read the
// picture back, run on CoreRaster and upload it again; a section at its
// identity is skipped, as CoreRaster returns the buffer itself there. The CPU
// route renders each damaged tile on its own task; the GPU route renders each
// row of damaged tiles as one region, the rows on their own tasks. With
// resident tiles (`residentTiles`, the GPU route's ResidentSurfaces) a region
// composites from them in one batch, so a frame uploads only the tiles that
// changed, those across the cores, and `composites` keeps the live route's
// base composites (PhotoLiveTone.swift). Export and `composite()` stay on
// `rendered(_:)` (CoreRaster directly), the reference both routes are held
// to. Linux-safe: the Metal backend is the app's to make.
import CoreColor
import CoreRaster
import CoreRender

/// Where Photo's canvas composite runs: on `preferred` where it can, else on the CPU.
public struct PhotoRenderRoute: Sendable {
    /// The GPU backend; nil draws everything on the CPU.
    public let preferred: (any RenderBackend)?
    /// Layer tiles kept on `preferred` between renders; nil uploads every tile a render composites.
    public let resident: ResidentSurfaces?
    /// The live route's base composites, one per region, kept while their layers are unchanged.
    public let composites = PhotoCompositeCache()

    public init(preferred: (any RenderBackend)? = nil, resident: ResidentSurfaces? = nil) {
        self.preferred = preferred
        self.resident = resident
    }

    /// The families the resident path composites with: every blend mode, so a batch never falls back.
    static let residentFamilies: Set<RenderOp> = [.composite, .blendSeparable, .blendNonSeparable]

    /// `resident` while it lives on `preferred`, `preferred` is healthy and runs every blend family;
    /// else nil, and renders upload their tiles (a backend still compiling, or one without in-place blends).
    public var residentTiles: ResidentSurfaces? {
        guard let resident, let preferred, preferred.isHealthy, resident.backend.name == preferred.name,
            Self.residentFamilies.isSubset(of: preferred.supports)
        else { return nil }
        return resident
    }

    /// Every op on the CPU backend.
    public static let cpu = PhotoRenderRoute()

    /// A dispatcher for one render, over a CPU backend of its own.
    public func dispatcher() -> RenderDispatcher {
        RenderDispatcher(preferred: preferred, fallback: CPUBackend())
    }

    /// Whether a render goes to the GPU, one region per frame rather than one task per tile.
    public var isGPU: Bool { preferred?.isHealthy == true }
}

extension PhotoWorkspace {
    /// `rect` of the canvas through `dispatcher` as display bytes (sRGB,
    /// straight alpha, row-major) and the name of the backend that encoded them.
    func displayed(
        _ rect: PixelRect, on dispatcher: RenderDispatcher, resident: ResidentSurfaces? = nil
    ) throws -> (bytes: [UInt8], backend: String) {
        let picture = try renderedSurface(rect, on: dispatcher, resident: resident)
        defer { dispatcher.release(picture) }
        let backend = dispatcher.backend(for: .display).name
        return (try dispatcher.display(picture, colorSpace: .sRGB), backend)
    }

    /// `rect` of the canvas composited and adjusted through `dispatcher`, as
    /// `rendered(_:)` makes it on CoreRaster. The caller releases the surface.
    /// With `resident`, the layers' tiles come from it and composite in one batch (`residentComposited`).
    public func renderedSurface(
        _ rect: PixelRect, on dispatcher: RenderDispatcher, resident: ResidentSurfaces? = nil
    ) throws -> RenderSurface {
        guard let canvas, let outer = rect.expanded(by: adjustments.blurMargin).intersection(canvas.rect),
            let inner = rect.intersection(canvas.rect)
        else { throw RasterError.invalid("region \(rect) is outside the image") }
        let picture = try resident.flatMap { try residentComposited(outer, on: dispatcher, resident: $0) }
        let adjusted = try adjustments.applied(to: picture ?? composited(outer, on: dispatcher), on: dispatcher)
        guard outer != inner else { return adjusted }
        defer { dispatcher.release(adjusted) }
        return try dispatcher.cropped(
            adjusted, x: inner.x - outer.x, y: inner.y - outer.y, width: inner.width, height: inner.height)
    }

    /// The visible layers over transparency in `rect`, bottom first, from `resident` (`residentComposited(_:layers:
    /// on:resident:)`). Nil when a visible layer needs the other path: an adjustment layer, or an opacity
    /// CoreRaster rejects.
    func residentComposited(_ rect: PixelRect, on dispatcher: RenderDispatcher, resident: ResidentSurfaces) throws
        -> RenderSurface?
    {
        let shown = layers.reversed().filter { $0.isVisible && $0.opacity > 0 }
        guard
            shown.allSatisfy({ layer in
                if case .adjustment = layer.kind { return false }
                return (0...1).contains(Float(layer.opacity))
            })
        else { return nil }
        return try residentComposited(rect, layers: shown, on: dispatcher, resident: resident)
    }

    /// The pixel layers `layers` (bottom first) over transparency in `rect`: their tiles under `rect` synced to
    /// `resident` (`residentSteps`), then one batched composite onto a blank surface, whole tiles, no CPU scan
    /// of their pixels.
    func residentComposited(_ rect: PixelRect, layers: [PhotoLayer], on dispatcher: RenderDispatcher,
                            resident: ResidentSurfaces) throws -> RenderSurface {
        let steps = try residentSteps(layers, in: rect, resident: resident)
        var picture = try dispatcher.blank(width: rect.width, height: rect.height)
        do {
            try dispatcher.composite(steps, onto: &picture)
        } catch {
            dispatcher.release(picture)
            throw error
        }
        return picture
    }

    /// The pixel layers' tiles under `rect` (bottom first) as composite steps onto a surface of `rect`, each
    /// synced to `resident` (an unchanged tile is not uploaded again, a clear one is skipped). The changed tiles
    /// upload across the cores, as the CPU route renders its tiles; the steps stay in order.
    func residentSteps(_ layers: [PhotoLayer], in rect: PixelRect, resident: ResidentSurfaces) throws -> [CompositeStep] {
        var tiles: [(key: ResidentKey, pixels: PixelBuffer, at: PixelRect, layer: PhotoLayer)] = []
        for layer in layers {
            guard let tiled = pixels[layer.id] else { continue }
            let region = PixelRect(x: rect.x - layer.offsetX, y: rect.y - layer.offsetY, width: rect.width, height: rect.height)
            for i in tiled.tileIndices(in: region) where tiled.tiles.indices.contains(i) {
                let at = tiled.tileRect(i).offsetBy(layer.offsetX - rect.x, layer.offsetY - rect.y)
                tiles.append((ResidentKey(layer: layer.id, tile: i), tiled.tiles[i], at, layer))
            }
        }
        let surfaces = try PhotoLayerComposite.inParallel(tiles.count) { [tiles] i in
            try resident.surface(tiles[i].key, pixels: tiles[i].pixels)
        }
        return zip(tiles, surfaces).compactMap { tile, surface in
            surface.map {
                CompositeStep($0, x: tile.at.x, y: tile.at.y, mode: tile.layer.blendMode, opacity: Float(tile.layer.opacity))
            }
        }
    }

    /// The visible layers over transparency in `rect`, bottom first.
    func composited(_ rect: PixelRect, on dispatcher: RenderDispatcher) throws -> RenderSurface {
        var picture = try dispatcher.surface(PixelBuffer(width: rect.width, height: rect.height))
        do {
            for layer in layers.reversed() where layer.isVisible && layer.opacity > 0 {
                if case .adjustment = layer.kind {
                    // No RenderOp runs an adjustment layer: read back, CoreRaster, upload again.
                    let content = LayerContent(
                        layer: layer, pixels: pixels[layer.id], mask: layer.isMaskEnabled ? masks[layer.id] : nil)
                    let done = try PhotoLayerComposite.composite(
                        content, onto: dispatcher.read(picture), origin: (x: rect.x, y: rect.y),
                        adjusting: services.adjustmentLayers, masking: services.masking)
                    picture = try Self.replace(picture, with: dispatcher.surface(done), on: dispatcher)
                } else if let tiled = pixels[layer.id] {
                    try composite(tiled, of: layer, onto: &picture, at: rect, on: dispatcher)
                }
            }
        } catch {
            dispatcher.release(picture)
            throw error
        }
        return picture
    }

    /// `layer`'s tiles under `rect` composited onto `picture`, a surface of
    /// `rect`. Masks are ignored, as PhotoLayerComposite ignores them until PV-5.
    private func composite(
        _ tiled: TiledPixels, of layer: PhotoLayer, onto picture: inout RenderSurface, at rect: PixelRect,
        on dispatcher: RenderDispatcher
    ) throws {
        let region = PixelRect(x: rect.x - layer.offsetX, y: rect.y - layer.offsetY, width: rect.width, height: rect.height)
        let mode = layer.blendMode, opacity = Float(layer.opacity), inRange = (0...1).contains(opacity)
        for i in tiled.tileIndices(in: region) where tiled.tiles.indices.contains(i) {
            let tile = tiled.tiles[i]
            let at = tiled.tileRect(i).offsetBy(layer.offsetX - rect.x, layer.offsetY - rect.y)
            if inRange, try PhotoLayerComposite.replaces(
                tile, width: rect.width, height: rect.height, dx: at.x, dy: at.y, mode: mode, opacity: opacity)
            {
                picture = try Self.replace(picture, with: dispatcher.surface(tile), on: dispatcher)
                continue
            }
            var (source, x, y) = (tile, at.x, at.y)
            // Out of range, CoreRaster throws for the opacity: send the whole tile so the error comes back.
            if inRange {
                let over = PixelRect(x: -at.x, y: -at.y, width: rect.width, height: rect.height)
                guard let painted = try PhotoLayerComposite.paintedRect(of: tile, in: over) else { continue }
                if painted.width != tile.width || painted.height != tile.height {
                    source = try tile.cropped(x: painted.x, y: painted.y, width: painted.width, height: painted.height)
                }
                (x, y) = (at.x + painted.x, at.y + painted.y)
            }
            let surface = try dispatcher.surface(source)
            defer { dispatcher.release(surface) }
            try dispatcher.composite(surface, onto: &picture, x: x, y: y, mode: mode, opacity: opacity)
        }
    }

    /// `next`, with `old` released.
    static func replace(_ old: RenderSurface, with next: RenderSurface, on dispatcher: RenderDispatcher) -> RenderSurface {
        dispatcher.release(old)
        return next
    }
}

extension AdjustmentSettings {
    /// The enabled adjustments applied to `surface` through `dispatcher`, in
    /// `applied(to:)`'s order. Takes `surface`: it is released on the way.
    func applied(to surface: RenderSurface, on dispatcher: RenderDispatcher) throws -> RenderSurface {
        var result = surface
        func step(_ next: () throws -> RenderSurface) throws {
            result = PhotoWorkspace.replace(result, with: try next(), on: dispatcher)
        }
        do {
            // Each step is skipped at its identity, where CoreRaster returns the buffer itself, so the
            // result is the same bits and an untouched section costs the GPU no round trip.
            if isEnabled(.exposure), exposure != 0 { try step { try dispatcher.adjusted(result, .exposure(stops: exposure)) } }
            if isEnabled(.levels), [blackPoint, whitePoint, gamma] != [0, 1, 1] {
                try step {
                    try dispatcher.adjusted(
                        result,
                        .levels(inBlack: blackPoint, inWhite: whitePoint, gamma: gamma, outBlack: 0, outWhite: 1,
                                encoding: .sRGB))
                }
            }
            if isEnabled(.curves), !curvePoints.allSatisfy({ $0.x == $0.y }) {
                try step { try dispatcher.adjusted(result, .curves(points: curvePoints, encoding: .sRGB)) }
            }
            if isEnabled(.hueSaturation), hue != 0 || saturation != 0 || lightness != 0 {
                // No ToneAdjustment for it: read back, CoreRaster, upload again.
                try step {
                    try dispatcher.surface(
                        dispatcher.read(result).hueSaturation(hue: hue, saturation: saturation, lightness: lightness))
                }
            }
            if blurMargin > 0 { try step { try dispatcher.gaussianBlur(result, sigma: blurSigma) } }
        } catch {
            dispatcher.release(result)
            throw error
        }
        return result
    }
}
