// LiveToneSurface.swift: one resident picture on the GPU (suite-imaging IM-2
// stub, IM-5 body, lifted from Photo's PhotoLiveTone route, photo #3144). The
// base is cut into square tiles (`tileSize`), each uploaded once as its own
// surface on a CoreRenderMetal backend and kept there. A tone step folds its
// program into the display write (`MetalBackend.display(_:into:...tone:)`, the
// `display_tone` pass): one write per tile in the region, no composite, no
// upload, no readback. The unsharp pass runs once per tile over the base, from
// a crop padded by the blur radius so tile seams match a whole-picture sharpen,
// and is cached until the base under it or its parameters change.
// `replaceBase` re-uploads only the tiles a pixel edit damaged and drops the
// sharpened tiles whose padded crop touches the damage. macOS only, inside
// `#if canImport(Metal)`; the only Metal file outside SuiteUI's canvas host
// besides its Route/ siblings (ImagingBoundaryTests).
//
// The base is CoreRaster's PixelBuffer: the contract's TiledPixels is
// PhotoModel's type, which SuiteImaging can't import; the Photo adapter
// (IM-8) hands over its flattened pixels.
#if canImport(Metal)
import CoreColor
import CoreRaster
import CoreRender
import CoreRenderMetal
import Metal

public final class LiveToneSurface {
    /// tone-controls' `ToneRules.unsharp`: run once over the base and cached
    /// until the base or these change.
    public struct UnsharpParameters: Hashable, Sendable {
        public var amount, sigma, threshold: Double

        public init(amount: Double, sigma: Double, threshold: Double) {
            self.amount = amount
            self.sigma = sigma
            self.threshold = threshold
        }

        /// The blur's reach in pixels (CoreRaster's ceil(3 sigma)), plus one.
        var margin: Int {
            guard sigma.isFinite, sigma > 0, sigma < 10_000 else { return 0 }
            return Int((3 * sigma).rounded(.up)) + 1
        }
    }

    private let backend: MetalBackend
    private let tileSize: Int
    private var base: PixelBuffer
    /// The resident base, one surface per tile, row-major.
    private var tiles: [RenderSurface?]
    /// Each tile's sharpened base under `sharpenedWith`.
    private var sharpened: [RenderSurface?]
    private var sharpenedWith: UnsharpParameters?

    /// Base tiles uploaded so far.
    public private(set) var uploads = 0
    /// Display writes so far (one per tile drawn).
    public private(set) var writes = 0
    /// Tiles sharpened so far.
    public private(set) var sharpenPasses = 0
    /// Bytes read back from the GPU so far (only the sharpen pass reads).
    public private(set) var bytesRead = 0

    /// `base` uploaded to `device` in `tileSize` tiles and kept resident.
    /// Throws what `MetalBackend.init` or an upload throws.
    public init(device: any MTLDevice, base: PixelBuffer, tileSize: Int = 512) throws {
        backend = try MetalBackend(device: device, cacheURL: nil)
        self.tileSize = max(tileSize, 1)
        self.base = base
        tiles = []
        sharpened = []
        try layOut()
    }

    deinit {
        for surface in tiles.compactMap({ $0 }) + sharpened.compactMap({ $0 }) { backend.release(surface) }
    }

    private var columns: Int { (base.width + tileSize - 1) / tileSize }
    private var rows: Int { (base.height + tileSize - 1) / tileSize }

    /// Tile `index`'s rectangle in the picture.
    private func rect(_ index: Int) -> TileRect {
        let (column, row) = (index % max(columns, 1), index / max(columns, 1))
        let (x, y) = (column * tileSize, row * tileSize)
        return TileRect(x: x, y: y, width: min(tileSize, base.width - x), height: min(tileSize, base.height - y))
    }

    private static func intersects(_ a: TileRect, _ b: TileRect) -> Bool {
        a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height
    }

    /// Empties both caches and uploads every tile of `base`.
    private func layOut() throws {
        for surface in tiles.compactMap({ $0 }) + sharpened.compactMap({ $0 }) { backend.release(surface) }
        tiles = Array(repeating: nil, count: columns * rows)
        sharpened = tiles
        for index in tiles.indices { _ = try resident(index) }
    }

    /// Tile `index` of the base on the GPU: the kept surface, else uploaded now.
    private func resident(_ index: Int) throws -> RenderSurface {
        if let held = tiles[index] { return held }
        let r = rect(index)
        let made = try backend.surface(try base.cropped(x: r.x, y: r.y, width: r.width, height: r.height))
        tiles[index] = made
        uploads += 1
        return made
    }

    /// Tile `index` sharpened by `unsharp`: the kept one, else made now from
    /// the base cropped with a margin and sharpened on the GPU.
    private func sharp(_ index: Int, _ unsharp: UnsharpParameters) throws -> RenderSurface {
        if sharpenedWith != unsharp {
            for surface in sharpened.compactMap({ $0 }) { backend.release(surface) }
            sharpened = Array(repeating: nil, count: tiles.count)
            sharpenedWith = unsharp
        }
        if let held = sharpened[index] { return held }
        let r = rect(index), m = unsharp.margin
        let (x0, y0) = (max(r.x - m, 0), max(r.y - m, 0))
        let (x1, y1) = (min(r.x + r.width + m, base.width), min(r.y + r.height + m, base.height))
        let padded = try backend.surface(try base.cropped(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
        defer { backend.release(padded) }
        let whole = try backend.unsharpMask(padded, amount: unsharp.amount, sigma: unsharp.sigma, threshold: unsharp.threshold)
        defer { backend.release(whole) }
        bytesRead += padded.width * padded.height * 16  // the Metal unsharp reads its source back
        let made = try backend.cropped(whole, x: r.x - x0, y: r.y - y0, width: r.width, height: r.height)
        sharpened[index] = made
        sharpenPasses += 1
        return made
    }

    /// A pixel edit: re-uploads only the `damaged` tiles and drops the
    /// sharpened tiles near them; a base of a new size is laid out again.
    /// Tone steps never call it. A failed upload leaves the tile to upload on
    /// the next draw.
    public func replaceBase(_ base: PixelBuffer, damaged: [TileRect]) {
        let resized = base.width != self.base.width || base.height != self.base.height
        self.base = base
        if resized {
            try? layOut()
            return
        }
        let margin = sharpenedWith?.margin ?? 0
        for index in tiles.indices {
            let r = rect(index)
            let reach = TileRect(x: r.x - margin, y: r.y - margin, width: r.width + 2 * margin, height: r.height + 2 * margin)
            if let held = sharpened[index], damaged.contains(where: { Self.intersects(reach, $0) }) {
                backend.release(held)
                sharpened[index] = nil
            }
            guard damaged.contains(where: { Self.intersects(r, $0) }) else { continue }
            if let held = tiles[index] { backend.release(held) }
            tiles[index] = nil
            _ = try? resident(index)
        }
    }

    /// `program` over the resident base, with `unsharp` from its cache, into
    /// `target` at picture coordinates: one display write (sRGB,
    /// premultiplied) per tile `region` touches. `target` is an rgba8Unorm or
    /// bgra8Unorm texture with shaderWrite usage that covers those tiles.
    /// Throws what `ToneProgram(operations:)` or the display write throws.
    public func draw(_ program: [ToneProgram.Operation], unsharp: UnsharpParameters?, into target: any MTLTexture,
                     region: TileRect) throws {
        let tone = try ToneProgram(operations: program)
        for index in tiles.indices where Self.intersects(rect(index), region) {
            let r = rect(index)
            let picture: RenderSurface
            if let unsharp { picture = try sharp(index, unsharp) } else { picture = try resident(index) }
            try backend.display(picture, into: target, x: r.x, y: r.y, colorSpace: .sRGB, premultiplied: true, tone: tone)
            writes += 1
        }
    }
}
#endif
