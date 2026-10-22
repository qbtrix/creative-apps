// LayeredToneBase.swift: a layered picture kept live on the GPU (suite-imaging
// IM-17, slice IM-gpu, lifted from Photo's PhotoLiveTone `liveStack` and
// `liveRegion`, photo #3144). Each pixel layer is cut into square tiles
// (`tileSize`), uploaded once and kept resident. A region (one tile) is
// composited bottom-up on a CoreRenderMetal backend: a pixel layer as one
// batched composite of its resident tile, an adjustment layer as one
// `ToneProgram` pass over the picture so far (blended back with its mode and
// opacity when those aren't normal and 1). The region's composite is cached
// and is the base a tone step draws from, as `LiveToneSurface.draw` draws its
// base: one display write per region with the step's program folded in, no
// composite, no upload, no readback. `replacePixels` re-uploads only the
// damaged tiles of the edited layer and drops only their regions' composites;
// nothing here reads back. macOS only, inside `#if canImport(Metal)`
// (ImagingBoundaryTests: Route/ is SuiteImaging's Metal home).
//
// Layers are CoreRaster PixelBuffers the size of the picture: the contract's
// TiledPixels and PhotoLayer are PhotoModel's types, which SuiteImaging can't
// import; the Photo adapter (IM-8) hands over its layers' pixels.
#if canImport(Metal)
import CoreColor
import CoreRaster
import CoreRender
import CoreRenderMetal
import Metal

public final class LayeredToneBase {
    /// One layer of the stack.
    public struct Layer: Sendable {
        public enum Kind: Sendable {
            /// Pixels the size of the picture.
            case pixels(PixelBuffer)
            /// An adjustment layer: its tone operations, run over everything under it.
            case adjustment([ToneProgram.Operation])
        }

        public var kind: Kind
        public var blendMode: BlendMode
        public var opacity: Float

        public init(_ kind: Kind, blendMode: BlendMode = .normal, opacity: Float = 1) {
            self.kind = kind
            self.blendMode = blendMode
            self.opacity = opacity
        }
    }

    /// A layer as the GPU holds it: its resident tiles, or its compiled program.
    private enum Held {
        case pixels(PixelBuffer, [RenderSurface?])
        case adjustment(ToneProgram)
    }

    private let backend: MetalBackend
    private let tileSize: Int
    private let width: Int, height: Int
    private var layers: [Layer]
    private var held: [Held]
    /// Each region's composite of the whole stack, row-major.
    private var composited: [RenderSurface?]

    /// Layer tiles uploaded so far.
    public private(set) var uploads = 0
    /// Region composites made so far.
    public private(set) var composites = 0
    /// Display writes so far (one per region drawn).
    public private(set) var writes = 0
    /// Bytes read back from the GPU so far: none on this route.
    public private(set) var bytesRead = 0

    /// `layers` (bottom first) of a `width` x `height` picture, uploaded to
    /// `device` in `tileSize` tiles and kept resident. Throws
    /// `RenderError.raster` for a pixel layer of another size, and what
    /// `MetalBackend.init`, an upload or `ToneProgram(operations:)` throws.
    public init(device: any MTLDevice, width: Int, height: Int, layers: [Layer], tileSize: Int = 512) throws {
        backend = try MetalBackend(device: device, cacheURL: nil)
        self.tileSize = max(tileSize, 1)
        self.width = max(width, 0)
        self.height = max(height, 0)
        self.layers = layers
        held = []
        composited = []
        let count = columns * rows
        composited = Array(repeating: nil, count: count)
        for layer in layers {
            switch layer.kind {
            case .pixels(let buffer):
                guard buffer.width == self.width, buffer.height == self.height else {
                    throw RenderError.raster("layered base: a \(buffer.width)x\(buffer.height) layer in a \(width)x\(height) picture")
                }
                held.append(.pixels(buffer, Array(repeating: nil, count: count)))
            case .adjustment(let operations):
                held.append(.adjustment(try ToneProgram(operations: operations)))
            }
        }
        for (layer, kept) in held.enumerated() {
            guard case .pixels = kept else { continue }
            for index in 0..<count { try resident(layer, index) }
        }
    }

    deinit {
        for case .pixels(_, let tiles) in held { for surface in tiles.compactMap({ $0 }) { backend.release(surface) } }
        for surface in composited.compactMap({ $0 }) { backend.release(surface) }
    }

    private var columns: Int { (width + tileSize - 1) / tileSize }
    private var rows: Int { (height + tileSize - 1) / tileSize }

    /// Region `index`'s rectangle in the picture.
    private func rect(_ index: Int) -> TileRect {
        let (column, row) = (index % max(columns, 1), index / max(columns, 1))
        let (x, y) = (column * tileSize, row * tileSize)
        return TileRect(x: x, y: y, width: min(tileSize, width - x), height: min(tileSize, height - y))
    }

    private static func intersects(_ a: TileRect, _ b: TileRect) -> Bool {
        a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height
    }

    /// Tile `index` of pixel layer `layer` on the GPU: the kept surface, else
    /// uploaded now. Throws `RenderError.raster` for an adjustment layer.
    @discardableResult
    private func resident(_ layer: Int, _ index: Int) throws -> RenderSurface {
        guard held.indices.contains(layer), case .pixels(let buffer, var tiles) = held[layer],
              tiles.indices.contains(index) else {
            throw RenderError.raster("layered base: tile \(index) of layer \(layer) is not a pixel tile")
        }
        if let kept = tiles[index] { return kept }
        let r = rect(index)
        let made = try backend.surface(try buffer.cropped(x: r.x, y: r.y, width: r.width, height: r.height))
        tiles[index] = made
        held[layer] = .pixels(buffer, tiles)
        uploads += 1
        return made
    }

    /// Region `index`'s composite of the stack: the kept one, else made now
    /// from the resident tiles on GPU passes and kept.
    private func composite(_ index: Int) throws -> RenderSurface {
        if let kept = composited[index] { return kept }
        let r = rect(index)
        var picture = try backend.blank(width: r.width, height: r.height)
        do {
            for (position, layer) in layers.enumerated() {
                guard held.indices.contains(position) else { continue }
                switch held[position] {
                case .pixels:
                    let tile = try resident(position, index)
                    try backend.composite([CompositeStep(tile, x: 0, y: 0, mode: layer.blendMode, opacity: layer.opacity)],
                                          onto: &picture)
                case .adjustment(let program):
                    let adjusted = try backend.adjusted(picture, tone: program)
                    if layer.blendMode == .normal, layer.opacity == 1 {
                        backend.release(picture)
                        picture = adjusted
                    } else {
                        defer { backend.release(adjusted) }
                        try backend.composite([CompositeStep(adjusted, x: 0, y: 0, mode: layer.blendMode, opacity: layer.opacity)],
                                              onto: &picture)
                    }
                }
            }
        } catch {
            backend.release(picture)
            throw error
        }
        composited[index] = picture
        composites += 1
        return picture
    }

    /// A pixel edit to layer `layer`: re-uploads only its `damaged` tiles and
    /// drops only those regions' composites. Tone steps never call it. Throws
    /// `RenderError.raster` for an adjustment layer, a layer out of range or
    /// pixels of another size; a failed upload leaves the tile to upload on
    /// the next draw.
    public func replacePixels(at layer: Int, _ buffer: PixelBuffer, damaged: [TileRect]) throws {
        guard held.indices.contains(layer), case .pixels(_, var tiles) = held[layer] else {
            throw RenderError.raster("layered base: layer \(layer) is not a pixel layer")
        }
        guard buffer.width == width, buffer.height == height else {
            throw RenderError.raster("layered base: a \(buffer.width)x\(buffer.height) edit in a \(width)x\(height) picture")
        }
        layers[layer].kind = .pixels(buffer)
        for index in tiles.indices where damaged.contains(where: { Self.intersects(rect(index), $0) }) {
            if let kept = tiles[index] { backend.release(kept) }
            tiles[index] = nil
            if composited.indices.contains(index), let kept = composited[index] {
                backend.release(kept)
                composited[index] = nil
            }
        }
        held[layer] = .pixels(buffer, tiles)
        for index in tiles.indices where tiles[index] == nil { _ = try? resident(layer, index) }
    }

    /// `program` over each region's cached composite, into `target` at picture
    /// coordinates: one display write (sRGB, premultiplied) per region
    /// `region` touches. `target` is an rgba8Unorm or bgra8Unorm texture with
    /// shaderWrite usage that covers those regions. Throws what
    /// `ToneProgram(operations:)`, a composite or the display write throws.
    public func draw(_ program: [ToneProgram.Operation], into target: any MTLTexture, region: TileRect) throws {
        let tone = try ToneProgram(operations: program)
        for index in composited.indices where Self.intersects(rect(index), region) {
            let r = rect(index)
            try backend.display(try composite(index), into: target, x: r.x, y: r.y, colorSpace: .sRGB, premultiplied: true,
                                tone: tone)
            writes += 1
        }
    }
}
#endif
