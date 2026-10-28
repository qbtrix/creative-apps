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
// A live stroke's render (`quietly`) is a drag frame: Free Transform's draft
// draws through its matrix, and the plain `show` that follows (the window
// taking the copy back) redraws the whole picture exactly, even at the same
// revision. A drag sample of a draft that lifts (PhotoTransformLift) draws nothing: the first renders the
// picture once without the draft's layer and lifts the layer's pixels onto the view's live layer (SuiteUI's CanvasLiveLayer), every
// later one only places them (`moveLift`), and the next plain picture drops the lift as it lands. Wherever a
// picture comes back as tiles (no presenter texture to write), a layer with nothing under it hides the picture
// instead of drawing an empty one. The lifted
// pixels are made once per Free Transform (when its draft first shows) and serve every drag of it. A lift that
// fails leaves its drag on the region path.
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
import CoreRaster
import CoreRender
import Foundation
import IOSurface
import Observation
import PhotoModel
import SuiteImaging
import SuiteUI

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
    /// The picture shown is a drag frame of Free Transform's draft: the next plain `show` redraws it exactly.
    @ObservationIgnored private var showsLiveDraft = false
    private var isRendering = false
    private var waiting: PhotoWorkspace?
    /// Free Transform's lift for the drag under way: its key, the latest placement, and whether the view
    /// shows it yet; nil with none.
    @ObservationIgnored private var lift: (key: PhotoTransformLift.Key, placement: AffineMatrix, shown: Bool)?
    /// A drag sample that lifts, waiting for the render in flight.
    @ObservationIgnored private var liftWaiting: PhotoWorkspace?
    /// A lift that failed: its drag draws through the region path instead.
    @ObservationIgnored private var refusedLift: PhotoTransformLift.Key?
    /// The live layer's pixels for the Free Transform up now, made once (when the draft first shows) and
    /// reused by every drag of it; dropped once no draft shows. Nil before then.
    @ObservationIgnored private var sprite: Sprite?
    /// The sprite being made off the main thread for this draft, so a show doesn't start a second.
    @ObservationIgnored private var preparing: PhotoTransformLift.Sprite?

    /// A live layer's pixels and what they were made from. The surface is only read once made.
    struct Sprite: @unchecked Sendable {
        let of: PhotoTransformLift.Sprite
        let surface: IOSurface
        let width: Int, height: Int
    }
    /// Called with each picture's revision as its tiles reach the view (the brush ink test times this).
    @ObservationIgnored var onPicture: ((Int) -> Void)?
    #if DEBUG
    /// Pictures every renderer in the process has handed its view, and the renders in flight across every
    /// renderer (0 once every queue drained): the idle-work tests read them.
    static var pictures = 0, inFlight = 0
    /// Every renderer alive (weakly), so a test finds its own window's (`rendering(into:)`) and counts only its work.
    static let all = NSHashTable<AnyObject>.weakObjects()
    /// This renderer's live-layer pixel sets made (one per Free Transform while a draft's pixels hold), and lifts.
    @ObservationIgnored private(set) var spritesMade = 0
    @ObservationIgnored private(set) var liftsRun = 0
    /// Lifts every renderer in the process has started (each makes one layer surface).
    static var lifts = 0
    #endif
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

    init() {
        #if DEBUG
        Self.all.add(self)
        #endif
    }

    #if DEBUG
    /// No render running or waiting and no live-layer pixels being made.
    var isSettled: Bool { isIdle && preparing == nil && liftWaiting == nil }

    /// The renderer drawing into `view`; nil when none is.
    static func rendering(into view: CanvasHostView) -> CanvasRenderer? {
        all.allObjects.lazy.compactMap { $0 as? CanvasRenderer }.first { $0.tiles.attachedView === view }
    }
    #endif

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
        if quietly, moveLift(workspace) { return }
        // Any other picture replaces the lift: one not shown yet is dropped now, a shown one as the picture lands.
        if lift?.shown != true { (lift, liftWaiting) = (nil, nil) }
        prepareSprite(for: workspace)
        quiet = quietly
        guard let canvas = workspace.canvas else {
            tiles.clear()
            (revision, milliseconds, waiting) = (nil, nil, nil)
            return
        }
        let sameSize = canvas.width == tiles.width && canvas.height == tiles.height
        // A drag's revision is shown by the pacer's apply, then asked for again by
        // the window's revision change: the second ask has nothing to draw, unless
        // the picture is a drag frame and this ask is the exact one.
        let exact = showsLiveDraft && !quietly
        if sameSize, workspace.revision == revision, failure == nil, !redrawAll, !exact { return }
        guard !isRendering else {
            waiting = workspace
            return
        }
        isRendering = true
        #if DEBUG
        Self.inFlight += 1
        #endif
        var since = sameSize && !redrawAll && !exact ? revision : nil
        let route = self.route
        redrawAll = false
        // The resident GPU path draws into the Metal presenter's texture; a new texture starts empty.
        var target: PhotoDisplayTarget?
        if route.isGPU, route.residentTiles != nil, let gpu = route.preferred.flatMap(ImagingGPU.backend),
            let resident = tiles.residentTarget(width: canvas.width, height: canvas.height, on: gpu)
        {
            target = resident.target
            if resident.isNew { since = nil }
        }
        Task { [since, target, quietly] in
            do {
                let update = try await PhotoRenderer.update(workspace, since: since, route: route, target: target, live: quietly)
                tiles.apply(update, prepared: await Self.prepared(update))
                if lift?.shown == true {
                    tiles.dropLift()
                    lift = nil
                }
                showsLiveDraft = update.liveDraft
                if backend != update.backend { backend = update.backend }
                #if DEBUG
                Self.pictures += 1
                #endif
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
            finished()
        }
    }

    /// A render is done: release what `use` dropped while it drew, then draw what waited.
    private func finished() {
        isRendering = false
        #if DEBUG
        Self.inFlight -= 1
        #endif
        for dropped in retired { dropped.composites.removeAll() }
        retired = []
        if let latest = waiting {
            waiting = nil
            show(latest, quietly: quiet)
        } else if let lifting = liftWaiting {
            liftWaiting = nil
            if lift?.key == lifting.liftKey { runLift(lifting) }
        }
    }

    /// A drag sample of a draft that lifts: the first lifts it (`runLift`), the rest place it. False when the
    /// draft doesn't lift, so the sample draws as a drag frame.
    private func moveLift(_ workspace: PhotoWorkspace) -> Bool {
        guard workspace.canvas != nil, let key = workspace.liftKey, key != refusedLift,
            let placement = workspace.liftPlacement
        else { return false }
        if let up = lift, up.key == key {
            lift?.placement = placement
            if up.shown { tiles.moveLift(placement) }
            return true
        }
        if lift?.shown == true { tiles.dropLift() }
        lift = (key, placement, false)
        // The picture under the lift lacks the layer: the next plain picture redraws all of it.
        showsLiveDraft = true
        if isRendering { liftWaiting = workspace } else { runLift(workspace) }
        return true
    }

    /// Renders `workspace` without its draft's layer, once, and lifts the layer's pixels onto the view at the
    /// latest placement, unless a plain picture was asked for meanwhile. The pixels and the render are made off
    /// the main thread.
    private func runLift(_ workspace: PhotoWorkspace) {
        guard let canvas = workspace.canvas, let key = workspace.liftKey else { return }
        isRendering = true
        #if DEBUG
        Self.inFlight += 1
        Self.lifts += 1
        liftsRun += 1
        #endif
        let route = self.route
        redrawAll = false
        var target: PhotoDisplayTarget?
        if route.isGPU, route.residentTiles != nil, let gpu = route.preferred.flatMap(ImagingGPU.backend),
            let resident = tiles.residentTarget(width: canvas.width, height: canvas.height, on: gpu)
        {
            target = resident.target
        }
        Task { [target] in
            do {
                // The pixels are the same for every drag of the draft: made once, here or when the draft showed.
                let wanted = workspace.liftSprite
                var made = sprite.flatMap { $0.of == wanted ? $0 : nil }
                if made == nil {
                    made = try await Self.sprite(of: workspace)
                    #if DEBUG
                    spritesMade += 1
                    #endif
                }
                guard let made, let base = workspace.liftedBase else { throw RasterError.invalid("the layer can't lift") }
                if sprite?.of != made.of { sprite = made }
                // Wherever a picture comes back as tiles (the CPU, or the GPU with no presenter texture to write), a
                // layer with nothing under it hides the picture instead of drawing an empty one: no tile surfaces. A
                // render into the presenter's texture costs no surfaces, so it still draws the picture under it.
                let alone = target == nil && workspace.liftsAlone
                let update = alone ? nil : try await PhotoRenderer.update(base, since: nil, route: route, target: target)
                var prepared: [PixelRect: CanvasTiles.Prepared]?
                if let update { prepared = await Self.prepared(update) }
                if let up = lift, up.key == key, !up.shown {
                    if let update { tiles.apply(update, prepared: prepared) }
                    tiles.lift(made.surface, width: made.width, height: made.height,
                               opacity: made.of.opacity, placement: up.placement, hidingPicture: alone)
                    lift?.shown = true
                    if let update, backend != update.backend { backend = update.backend }
                    #if DEBUG
                    if update != nil { Self.pictures += 1 }
                    #endif
                    revision = update?.revision ?? workspace.revision
                    if failure != nil { failure = nil }
                }
            } catch {
                // The drag goes on through the region path; the next plain picture redraws whatever this drew.
                refusedLift = key
                if lift?.key == key { lift = nil }
            }
            finished()
        }
    }

    /// Makes the live layer's pixels for `workspace`'s draft off the main thread when its Free Transform first
    /// shows, so the first drag only renders the picture under them; drops them once no draft shows.
    private func prepareSprite(for workspace: PhotoWorkspace) {
        guard let wanted = workspace.liftSprite else {
            if workspace.transformDraft == nil { (sprite, preparing) = (nil, nil) }
            return
        }
        guard sprite?.of != wanted, preparing != wanted else { return }
        preparing = wanted
        Task {
            let made = try? await Self.sprite(of: workspace)
            #if DEBUG
            if made != nil { spritesMade += 1 }
            #endif
            guard preparing == wanted else { return }
            preparing = nil
            if let made, sprite?.of != made.of { sprite = made }
        }
    }

    /// `workspace`'s live-layer pixels as an IOSurface, made off the main thread; nil when nothing lifts.
    nonisolated static func sprite(of workspace: PhotoWorkspace) async throws -> Sprite? {
        guard let of = workspace.liftSprite, let pixels = try workspace.liftedPixels(),
            let surface = CanvasTile.surface(premultipliedRGBA: pixels.rgba8, width: pixels.width, height: pixels.height)
        else { return nil }
        return Sprite(of: of, surface: surface, width: pixels.width, height: pixels.height)
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
