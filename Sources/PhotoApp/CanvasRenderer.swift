// CanvasRenderer.swift: keeps the canvas picture up to date without blocking
// the window. Each change to the workspace asks for the tiles that changed
// since the picture shown (PhotoRenderer.update), rendered off the main actor;
// a new image or a new size asks for all of them; asking again for the
// revision shown does nothing. While a render runs, newer
// requests wait and only the latest is drawn, so a fast brush stroke never
// queues up stale frames: a slider drag draws at most one picture at a time,
// always the newest. The render and the tiles' images and surfaces are made
// off the main thread, which only hands them to the view. The tiles go straight to the tile layers
// (CanvasTiles), not through SwiftUI, so no whole-canvas buffer or picture
// exists per event. `revision` says what is shown; the render time reaches the
// status line at most four times a second, and not from a live stroke's
// renders (`quietly`), since each readout re-runs the window's views. A failed
// render keeps the last good picture and its message. Renders go through
// `route` (CoreRender's dispatcher, CPU or Metal); `follow` keeps it on the
// app's View > Rendering choice, and a switch redraws the whole picture on the
// new backend at once (a waiting request redraws all of it too). `backend` names the backend that drew the picture shown.
// On the GPU route the renderer keeps the layer tiles resident on the backend
// (ResidentSurfaces) and, while the view draws through its Metal presenter,
// renders straight into the presenter's texture: no bytes come back, and an
// update only asks the view to present. The backend is the process's, so a
// tile set or composite cache the renderer drops (a switch, a closed window)
// is released there at once, or, while a render still draws from it, as
// that render ends (`retired`), so an idle renderer holds only its own.
// Presentation state only: it never changes the workspace.
import Combine
import CoreGraphics
import CoreRender
import CoreRenderMetal
import Foundation
import Observation
import PhotoModel

@MainActor @Observable
final class CanvasRenderer {
    let tiles = CanvasTiles()
    /// The revision the tiles show; nil with no image.
    private(set) var revision: Int?
    /// The latest render's time, published at most every `timing`.
    private(set) var milliseconds: Double?
    private(set) var failure: String?
    /// The latest render's time, every render.
    @ObservationIgnored private(set) var lastMilliseconds: Double?
    @ObservationIgnored private var timed = ContinuousClock.now - timing
    private static let timing = Duration.milliseconds(250)
    /// The latest ask was a live stroke's (`quietly`): its render time waits.
    @ObservationIgnored private var quiet = false
    private var isRendering = false
    private var waiting: PhotoWorkspace?
    /// Called with each picture's revision as its tiles reach the view (the brush ink test times this).
    @ObservationIgnored var onPicture: ((Int) -> Void)?
    /// Where renders run; `use` switches it.
    @ObservationIgnored private(set) var route = PhotoRenderRoute.cpu
    /// The backend that drew the picture shown ("cpu", or the GPU's name); nil before the first.
    private(set) var backend: String?
    /// The next render redraws every tile: the route changed.
    @ObservationIgnored private var redrawAll = false
    @ObservationIgnored private var following: AnyCancellable?

    /// Layer tiles kept on the GPU route's backend between renders; a new set when the backend changes.
    @ObservationIgnored private var resident: ResidentTiles?
    /// What `use` dropped while a render drew from it: released when that render ends.
    @ObservationIgnored private var retired: [(composites: PhotoCompositeCache, tiles: ResidentTiles?)] = []

    /// No render is running or waiting, so nothing dropped is still held.
    var isIdle: Bool { !isRendering && waiting == nil }

    /// Draws on `route` from now on: the next `show` redraws every tile there. A GPU route gets this
    /// renderer's resident tiles for its backend, so a frame uploads only the layer tiles that changed.
    func use(_ route: PhotoRenderRoute) {
        let (composites, tiles) = (self.route.composites, resident)
        defer {
            let dropped = (composites: composites, tiles: tiles === resident ? nil : tiles)
            if isRendering { retired.append(dropped) } else { dropped.composites.removeAll() }
        }
        if let gpu = route.preferred {
            if resident?.surfaces.backend.name != gpu.name { resident = ResidentTiles(backend: gpu) }
            self.route = PhotoRenderRoute(preferred: gpu, resident: resident?.surfaces)
        } else {
            (self.route, resident) = (route, nil)
        }
        redrawAll = true
    }

    /// Draws on `rendering`'s route now and after every change of its choice,
    /// calling `redraw` (the window's `show` of its workspace) each time. The
    /// renderer keeps no workspace of its own: a held copy would make the next
    /// brush write copy every tile it lands in.
    func follow(_ rendering: PhotoRendering, redraw: @escaping @MainActor () -> Void) {
        use(rendering.route)
        redraw()
        following = rendering.preference.observe { [weak self, weak rendering] _ in
            guard let self, let rendering else { return }
            use(rendering.route)
            redraw()
        }
    }

    /// Draws `workspace` once the render in flight, if any, is done.
    /// `quietly` leaves the status line's render time as it is.
    func show(_ workspace: PhotoWorkspace, quietly: Bool = false) {
        quiet = quietly
        guard let canvas = workspace.canvas else {
            tiles.clear()
            (revision, milliseconds, waiting) = (nil, nil, nil)
            return
        }
        let sameSize = canvas.width == tiles.width && canvas.height == tiles.height
        // A drag's revision is shown by the pacer's apply, then asked for again by
        // the window's revision change: the second ask has nothing to draw.
        if sameSize, workspace.revision == revision, failure == nil, !redrawAll { return }
        guard !isRendering else {
            waiting = workspace
            return
        }
        isRendering = true
        var since = sameSize && !redrawAll ? revision : nil
        let route = self.route
        redrawAll = false
        // The resident GPU path draws into the Metal presenter's texture; a new texture starts empty.
        var target: PhotoDisplayTarget?
        if route.isGPU, route.residentTiles != nil, let metal = route.preferred as? MetalBackend,
            let resident = tiles.residentTarget(width: canvas.width, height: canvas.height, on: metal)
        {
            target = resident.target
            if resident.isNew { since = nil }
        }
        Task { [since, target] in
            do {
                let update = try await PhotoRenderer.update(workspace, since: since, route: route, target: target)
                tiles.apply(update, prepared: await Self.prepared(update))
                if backend != update.backend { backend = update.backend }
                onPicture?(update.revision)
                lastMilliseconds = update.milliseconds
                if !quiet, ContinuousClock.now - timed >= Self.timing {
                    (milliseconds, timed) = (update.milliseconds, .now)
                }
                failure = nil
                revision = update.revision
            } catch {
                failure = "The picture couldn't be drawn: \(error)"
            }
            isRendering = false
            // The render that drew from what `use` dropped is done: release it.
            for dropped in retired { dropped.composites.removeAll() }
            retired = []
            if let latest = waiting {
                waiting = nil
                show(latest, quietly: quiet)
            }
        }
    }

    /// `update`'s tile images and surfaces, made off the main thread (a nonisolated async function runs on
    /// the global executor), so the main thread only hands them to the view.
    nonisolated static func prepared(_ update: PhotoTileUpdate) async -> [PixelRect: CanvasTiles.Prepared] {
        CanvasTiles.prepare(update)
    }

    /// 8-bit sRGB bytes as an image. `alpha` is `.last` for straight alpha,
    /// `.premultipliedLast` for premultiplied, `.noneSkipLast` for opaque pixels.
    nonisolated static func image(rgba8: [UInt8], width: Int, height: Int, alpha: CGImageAlphaInfo) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let provider = CGDataProvider(data: Data(rgba8) as CFData)
        else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: alpha.rawValue), provider: provider, decode: nil,
            shouldInterpolate: true, intent: .defaultIntent)
    }
}

/// A renderer's resident layer tiles, released on their backend once nothing holds them: neither the renderer
/// nor a render still drawing from them. Dropping a ResidentSurfaces alone leaves its surfaces on the backend.
private final class ResidentTiles: Sendable {
    let surfaces: ResidentSurfaces

    init(backend: any RenderBackend) {
        surfaces = ResidentSurfaces(backend: backend)
    }

    deinit { surfaces.removeAll() }
}
