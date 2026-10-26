// PhotoTileUpdate.swift: what the live canvas needs after an edit, the canvas
// tiles that changed and nothing else. `PhotoRenderer.update(_:since:)`
// renders the tiles damaged since the revision the canvas shows, in parallel,
// as premultiplied 8-bit sRGB (what Core Animation draws without converting),
// so a brush event costs its dirty tiles, never a copy of the whole canvas.
// With no revision shown (a new image, a new size) every tile comes, and the
// update says it is complete. The full-frame `render` stays the reference: the
// tiles laid where they belong equal its bytes, premultiplied the same way
// (`premultiplied(_:)`). While Free Transform is up, both draw the draft's
// layer through the draft (`transformPreview`, resampled once per update), so
// the cached base under it stands and only it and the layers above composite.
// The live canvas renders through a PhotoRenderRoute
// (CoreRender's dispatcher, CPU or GPU) and the update names the backend whose
// display encode made its bytes; `completeUpdate` (snapshots) stays on
// CoreRaster. A GPU route with resident tiles and a PhotoDisplayTarget writes
// each damaged region to the target (the app's Metal texture) and returns no
// bytes; when the target also runs a tone program (`writeToned`) and the
// backend runs one over a surface, a region takes the live route
// (PhotoLiveTone.swift): adjustments and adjustment layers as GPU passes over
// a cached composite, so a slider step composites nothing and reads nothing
// back. Linux-safe.
import CoreRaster
import CoreRender

/// Where a GPU route puts the picture instead of returning its bytes: `write` shows `surface`, the canvas's
/// `rect`, on screen with no readback (the app's writes it into its presenter's texture). `writeToned` does the
/// same with a tone program run on each pixel first, in the same pass (the app's Metal `display_tone`); nil
/// when the target can't, and every region then takes `write`.
public struct PhotoDisplayTarget: Sendable {
    public let write: @Sendable (_ surface: RenderSurface, _ rect: PixelRect) throws -> Void
    public let writeToned: (@Sendable (_ surface: RenderSurface, _ rect: PixelRect, _ tone: ToneProgram) throws -> Void)?

    public init(write: @escaping @Sendable (_ surface: RenderSurface, _ rect: PixelRect) throws -> Void,
                writeToned: (@Sendable (_ surface: RenderSurface, _ rect: PixelRect, _ tone: ToneProgram) throws -> Void)? = nil) {
        self.write = write
        self.writeToned = writeToned
    }
}

/// The canvas tiles that changed, ready for display.
public struct PhotoTileUpdate: Sendable {
    public struct Tile: Sendable, Equatable {
        /// Where the tile sits on the canvas, in pixels.
        public let rect: PixelRect
        /// rect.width x rect.height x 4 bytes, row-major, sRGB, premultiplied alpha.
        public let rgba8: [UInt8]
    }

    /// The canvas size the tiles belong to.
    public let width: Int
    public let height: Int
    public let revision: Int
    /// Whether `tiles` covers the whole canvas, so tiles shown before are stale.
    public let isComplete: Bool
    public let tiles: [Tile]
    public let milliseconds: Double
    /// The backend whose display encode made the bytes: CoreRender's CPU backend ("cpu") or the GPU's name.
    public let backend: String
    /// The damaged canvas tiles were written to a display target instead: `tiles` is empty.
    public var wroteTarget = false
}

extension PhotoRenderer {
    /// The tiles of `workspace` damaged since `revision`, or all of them with
    /// no revision, drawn through `route`. Throws `RasterError` with no image
    /// open or when an adjustment fails, and `RenderError` when a backend does.
    /// With resident tiles on the route (`residentTiles`) and a `target`, the GPU composites from them and
    /// writes each damaged region to `target`: no bytes come back, and `tiles` is empty.
    /// `live` is a drag sample's frame: Free Transform's draft draws through its matrix on each region (bilinear,
    /// no whole-layer resample), and the exact frame, Return's pixels, comes with the next plain update.
    public static func update(
        _ workspace: PhotoWorkspace, since revision: Int?, route: PhotoRenderRoute = .cpu,
        target: PhotoDisplayTarget? = nil, live: Bool = false
    ) async throws -> PhotoTileUpdate {
        guard let canvas = workspace.canvas else { throw RasterError.invalid("no image is open") }
        let clock = ContinuousClock()
        // Free Transform's draft draws live: its layer resampled once per update, then composited as any layer.
        let workspace = workspace.transformPreview
        let started = clock.now
        let damage = revision.map { workspace.damage(since: $0) } ?? .all
        // A new picture or size: the kept composites belong to the old regions.
        if revision == nil { route.composites.removeAll() }
        let rects = tiles(of: canvas, in: damage)
        let resident = route.isGPU ? route.residentTiles : nil
        resident?.prune(keeping: Set(workspace.layers.map(\.id)))
        let written = resident != nil && target != nil
        // The live route's plan is made once per update (its programs' tables), then every band runs it.
        let live = written && target?.writeToned != nil && route.preferred is any ToneRendering ? workspace.liveStack() : nil
        let (tiles, backend) = route.isGPU
            ? try await bandedTiles(workspace, rects, route: route, target: written ? target : nil, live: live)
            : try await dispatchedTiles(workspace, rects, route: route)
        let elapsed = clock.now - started
        var update = PhotoTileUpdate(
            width: canvas.width, height: canvas.height, revision: workspace.revision, isComplete: damage == .all,
            tiles: tiles.map { PhotoTileUpdate.Tile(rect: $0, rgba8: $1) },
            milliseconds: Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15,
            backend: backend)
        update.wroteTarget = written
        return update
    }

    /// `rects` rendered each on its own task and dispatcher, premultiplied.
    static func dispatchedTiles(
        _ workspace: PhotoWorkspace, _ rects: [PixelRect], route: PhotoRenderRoute
    ) async throws -> ([(PixelRect, [UInt8])], String) {
        let done = try await withThrowingTaskGroup(of: (PixelRect, [UInt8], String).self) { group in
            for rect in rects {
                group.addTask {
                    var (bytes, backend) = try workspace.displayed(rect, on: route.dispatcher(), cache: route.composites)
                    premultiply(&bytes)
                    return (rect, bytes, backend)
                }
            }
            var done: [(PixelRect, [UInt8], String)] = []
            done.reserveCapacity(rects.count)
            for try await tile in group { done.append(tile) }
            return done
        }
        return (done.map { ($0.0, $0.1) }, done.first?.2 ?? CPUBackend().name)
    }

    /// `rects` on the GPU: each row of tiles is one region, the rows on their
    /// own tasks, so a brush frame (a row or two) is one or two regions, and a
    /// whole picture's rows overlap their CPU-side work and GPU waits. (One region
    /// for an 8K picture measured 2.6 s against 0.27 s for tiles in parallel and
    /// 4.9 ms against 9.4 ms for a two-tile brush frame.)
    static func bandedTiles(
        _ workspace: PhotoWorkspace, _ rects: [PixelRect], route: PhotoRenderRoute, target: PhotoDisplayTarget? = nil,
        live: PhotoLiveStack? = nil
    ) async throws -> ([(PixelRect, [UInt8])], String) {
        let bands = Dictionary(grouping: rects, by: \.y).values
        let done = try await withThrowingTaskGroup(of: ([(PixelRect, [UInt8])], String).self) { group in
            for band in bands {
                group.addTask {
                    guard let target else { return try regionTiles(workspace, band, route: route) }
                    return try targetRegion(workspace, band, route: route, target: target, live: live)
                }
            }
            var done: [([(PixelRect, [UInt8])], String)] = []
            for try await band in group { done.append(band) }
            return done
        }
        return (done.flatMap(\.0), done.first?.1 ?? route.preferred?.name ?? CPUBackend().name)
    }

    /// `rects` (whole tiles of one rectangle, as `tiles(of:in:)` gives them)
    /// rendered as one region through one dispatcher, then cut into the tiles.
    static func regionTiles(
        _ workspace: PhotoWorkspace, _ rects: [PixelRect], route: PhotoRenderRoute
    ) throws -> ([(PixelRect, [UInt8])], String) {
        guard let minX = rects.map(\.x).min(), let minY = rects.map(\.y).min(),
            let maxX = rects.map(\.maxX).max(), let maxY = rects.map(\.maxY).max()
        else { return ([], route.preferred?.name ?? CPUBackend().name) }
        let area = PixelRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let (bytes, backend) = try workspace.displayed(
            area, on: route.dispatcher(), resident: route.residentTiles, cache: route.composites)
        let tiles = rects.map { rect in
            var tile = [UInt8]()
            tile.reserveCapacity(rect.width * rect.height * 4)
            for row in rect.y..<rect.maxY {
                let from = ((row - area.y) * area.width + rect.x - area.x) * 4
                tile.append(contentsOf: bytes[from..<(from + rect.width * 4)])
            }
            premultiply(&tile)
            return (rect, tile)
        }
        return (tiles, backend)
    }

    /// `rects` (whole tiles of one rectangle) rendered as one region from the route's resident tiles and
    /// written to `target`; no tiles come back. With `live` (and the target's `writeToned`), the region takes
    /// the live route (`PhotoWorkspace.liveRegion`).
    static func targetRegion(
        _ workspace: PhotoWorkspace, _ rects: [PixelRect], route: PhotoRenderRoute, target: PhotoDisplayTarget,
        live: PhotoLiveStack? = nil
    ) throws -> ([(PixelRect, [UInt8])], String) {
        let name = route.preferred?.name ?? CPUBackend().name
        guard let minX = rects.map(\.x).min(), let minY = rects.map(\.y).min(),
            let maxX = rects.map(\.maxX).max(), let maxY = rects.map(\.maxY).max()
        else { return ([], name) }
        let area = PixelRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let dispatcher = route.dispatcher()
        if let live, let toned = target.writeToned, let resident = route.residentTiles,
            let gpu = route.preferred as? any ToneRendering
        {
            try workspace.liveRegion(
                area, stack: live, on: dispatcher, resident: resident, tone: gpu, cache: route.composites, write: toned)
            return ([], name)
        }
        let picture = try workspace.renderedSurface(
            area, on: dispatcher, resident: route.residentTiles, cache: route.composites)
        defer { dispatcher.release(picture) }
        try target.write(picture, area)
        return ([], name)
    }

    /// Every tile of `workspace`, rendered one after another on the caller's
    /// thread, for a picture that can wait (snapshots). Throws as `update` does.
    public static func completeUpdate(_ workspace: PhotoWorkspace) throws -> PhotoTileUpdate {
        guard let canvas = workspace.canvas else { throw RasterError.invalid("no image is open") }
        let workspace = workspace.transformPreview
        let tiles = try tiles(of: canvas, in: .all).map { rect in
            var bytes = try workspace.rendered(rect).rgba8()
            premultiply(&bytes)
            return PhotoTileUpdate.Tile(rect: rect, rgba8: bytes)
        }
        return PhotoTileUpdate(
            width: canvas.width, height: canvas.height, revision: workspace.revision, isComplete: true, tiles: tiles,
            milliseconds: 0, backend: CPUBackend().name)
    }

    /// Straight-alpha RGBA bytes premultiplied, each color rounded to the
    /// nearest of `color x alpha / 255`. Opaque pixels stay as they are.
    public static func premultiplied(_ rgba8: [UInt8]) -> [UInt8] {
        var bytes = rgba8
        premultiply(&bytes)
        return bytes
    }

    /// `premultiplied(_:)` in place.
    static func premultiply(_ bytes: inout [UInt8]) {
        bytes.withUnsafeMutableBufferPointer { p in
            for i in stride(from: 0, to: p.count - 3, by: 4) where p[i + 3] != 255 {
                let a = UInt32(p[i + 3])
                for c in i..<(i + 3) { p[c] = UInt8((UInt32(p[c]) * a + 127) / 255) }
            }
        }
    }
}
