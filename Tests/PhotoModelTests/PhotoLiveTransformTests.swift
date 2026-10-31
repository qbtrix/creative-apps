// PhotoLiveTransformTests.swift: Free Transform's draft is live on the canvas (#5279). While the draft is up,
// each render draws its layer through the draft, on the CPU route and the GPU's one-region route (a CPU
// backend standing in, held bit for bit): a move or turn step changes the picture before Return, Return lays
// exactly the last preview (which is also the reference render of the committed layer), Escape gives the
// picture back, and a step after the first makes no new base under the draft's layer (PhotoCompositeCache).
// A drag's frames (`PhotoRenderer.update(live: true)`) draw the draft through its matrix on each region, bilinear,
// and never resample the whole layer (`CountingTransform` counts `applied`), on the GPU route's resident batch too;
// the exact frame after the drag is Return's pixels. The per-layer composite counts are IdleWorkTests' (AppSnapshotTests). Live transform
// services, so the preview is the real lanczos3 resample. Runs on Linux and macOS.
import CoreRaster
import CoreRender
import SuiteKernel
import Synchronization
import Testing

@testable import PhotoModel

@Suite struct PhotoLiveTransformTests {
    /// A 300 x 200 white image, a 60 x 40 red "Logo" at (120, 80) and a translucent blue wash over everything;
    /// the Logo selected with Free Transform begun.
    static func transforming(transform: any LayerTransforming = LiveTransform.make()) throws -> PhotoWorkspace {
        var services = PhotoServices.live
        services.transform = transform
        var workspace = PhotoWorkspace(services: services)
        try workspace.newCanvas(width: 300, height: 200)
        let red = TiledPixels(try PixelBuffer(width: 60, height: 40, fill: RGBA(r: 1, g: 0, b: 0, a: 1)))
        let logo = workspace.insertLayer(named: "Logo", pixels: red, kind: .pixels, at: 0)
        let at = try #require(workspace.index(of: logo))
        (workspace.layers[at].offsetX, workspace.layers[at].offsetY) = (120, 80)
        let blue = TiledPixels(try PixelBuffer(width: 300, height: 200, fill: RGBA(r: 0, g: 0, b: 0.3, a: 0.3)))
        _ = workspace.insertLayer(named: "Wash", pixels: blue, kind: .pixels, at: 0)
        workspace.selectLayer(logo)
        workspace.selectTool(.select)
        try workspace.beginTransform()
        return workspace
    }

    /// A fresh route on `shared`'s backend (with resident tiles of its own when `shared` has them), so no other
    /// test's kept composites or tiles count here.
    static func route(_ shared: PhotoRenderRoute) -> PhotoRenderRoute {
        PhotoRenderRoute(preferred: shared.preferred, resident: shared.resident.map { ResidentSurfaces(backend: $0.backend) })
    }

    /// The GPU route with resident layer tiles (its whole-stack batch), a CPU backend standing in.
    static let resident = PhotoRenderRoute(
        preferred: PhotoRenderRouteTests.standIn.preferred,
        resident: ResidentSurfaces(backend: PhotoRenderRouteTests.standIn.preferred!))

    static func turned(_ workspace: inout PhotoWorkspace, by degrees: Double) throws {
        let box = try #require(workspace.transformSelection)
        try workspace.setTransform(TransformRules.rotated(box, by: degrees), name: "Rotate", drag: nil)
    }

    @Test(arguments: [PhotoRenderRoute.cpu, PhotoRenderRouteTests.standIn])
    func aTurnShowsBeforeReturnAndReturnLaysThePreview(route shared: PhotoRenderRoute) async throws {
        var workspace = try Self.transforming()
        let route = Self.route(shared)
        let opened = try await PhotoRenderer.update(workspace, since: nil, route: route)

        try Self.turned(&workspace, by: 15)
        let preview = try await PhotoRenderer.update(workspace, since: opened.revision, route: route)
        #expect(preview.isComplete)
        #expect(PhotoRenderRouteTests.laid(preview) != PhotoRenderRouteTests.laid(opened),
                "the turn step left the canvas as it was before Return")

        try workspace.commitTransform()
        let committed = try await PhotoRenderer.update(workspace, since: preview.revision, route: route)
        #expect(committed.isComplete)
        #expect(PhotoRenderRouteTests.laid(committed) == PhotoRenderRouteTests.laid(preview),
                "Return laid other pixels than the last preview showed")
        let reference = PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8)
        #expect(PhotoRenderRouteTests.laid(preview) == reference, "the preview isn't the committed layer's reference")
    }

    @Test(arguments: [PhotoRenderRoute.cpu, PhotoRenderRouteTests.standIn])
    func aMoveDragShowsEachStepAndEscapeGivesThePictureBack(route shared: PhotoRenderRoute) async throws {
        var workspace = try Self.transforming()
        let route = Self.route(shared)
        let opened = try await PhotoRenderer.update(workspace, since: nil, route: route)

        workspace.drag(from: Mask.Point(x: 150, y: 100), to: Mask.Point(x: 170, y: 110))
        let first = try await PhotoRenderer.update(workspace, since: opened.revision, route: route)
        #expect(PhotoRenderRouteTests.laid(first) != PhotoRenderRouteTests.laid(opened), "the first move step didn't show")
        workspace.drag(from: Mask.Point(x: 150, y: 100), to: Mask.Point(x: 190, y: 125))
        let second = try await PhotoRenderer.update(workspace, since: first.revision, route: route)
        #expect(PhotoRenderRouteTests.laid(second) != PhotoRenderRouteTests.laid(first), "the second move step didn't show")
        workspace.endDrag()
        #expect(workspace.transformDraft != nil)

        workspace.cancelTransform()
        let cancelled = try await PhotoRenderer.update(workspace, since: second.revision, route: route)
        #expect(cancelled.isComplete)
        #expect(PhotoRenderRouteTests.laid(cancelled) == PhotoRenderRouteTests.laid(opened),
                "Escape didn't give the picture back")
    }

    /// The open keeps every region whole; the first turn step makes the base under the Logo once per region;
    /// every step after it lays the Logo and the wash on that base and makes nothing.
    @Test(arguments: [PhotoRenderRoute.cpu, PhotoRenderRouteTests.standIn])
    func aTurnStepAfterTheFirstMakesNoBase(route shared: PhotoRenderRoute) async throws {
        var workspace = try Self.transforming()
        let route = Self.route(shared)
        let canvas = try #require(workspace.canvas)
        let tiles = PhotoRenderer.tiles(of: canvas, in: .all)
        let regions = route.isGPU ? Set(tiles.map(\.y)).count : tiles.count
        var shown = try await PhotoRenderer.update(workspace, since: nil, route: route)
        #expect(route.composites.made == regions)

        try Self.turned(&workspace, by: 5)
        shown = try await PhotoRenderer.update(workspace, since: shown.revision, route: route)
        #expect(route.composites.made == regions * 2, "the first step makes the base under the Logo once per region")
        for _ in 0..<3 {
            try Self.turned(&workspace, by: 5)
            shown = try await PhotoRenderer.update(workspace, since: shown.revision, route: route)
        }
        #expect(route.composites.made == regions * 2, "a later step composited the layers under the Logo again")
    }

    /// A drag's frames never resample the whole layer: each draws the draft through its matrix and changes the
    /// canvas; the exact frame after the drag resamples once, and Return lays exactly that frame.
    @Test(arguments: [PhotoRenderRoute.cpu, PhotoRenderRouteTests.standIn, resident])
    func aDragFrameDrawsTheDraftWithoutResamplingTheLayer(route shared: PhotoRenderRoute) async throws {
        let counting = CountingTransform()
        var workspace = try Self.transforming(transform: counting)
        let route = Self.route(shared)
        var shown = try await PhotoRenderer.update(workspace, since: nil, route: route)
        for step in 1...3 {
            try Self.turned(&workspace, by: 5)
            let frame = try await PhotoRenderer.update(workspace, since: shown.revision, route: route, live: true)
            #expect(frame.isComplete)
            #expect(PhotoRenderRouteTests.laid(frame) != PhotoRenderRouteTests.laid(shown), "drag step \(step) left the canvas as it was")
            shown = frame
        }
        #expect(counting.resamples == 0, "a drag frame resampled the whole layer (\(counting.resamples) resamples in 3 frames)")

        let exact = try await PhotoRenderer.update(workspace, since: nil, route: route)
        #expect(counting.resamples == 1, "the exact frame after the drag resampled \(counting.resamples) times, not once")
        #expect(PhotoRenderRouteTests.laid(exact) != PhotoRenderRouteTests.laid(shown), "the exact frame is the bilinear drag frame")
        try workspace.commitTransform()
        let committed = try await PhotoRenderer.update(workspace, since: exact.revision, route: route)
        #expect(PhotoRenderRouteTests.laid(committed) == PhotoRenderRouteTests.laid(exact),
                "Return laid other pixels than the frame after the drag showed")
    }

    /// The drag's first frames make the base under the Logo once per region (on a route whose open took the
    /// resident batch, the cache learns the stack on the first frame and splits it on the second, as a Move does);
    /// every frame after lays the Logo and the wash on that base, makes nothing, and still changes the canvas (the
    /// draft is in the base's key).
    @Test(arguments: [PhotoRenderRoute.cpu, PhotoRenderRouteTests.standIn, resident])
    func aDragFrameAfterTheFirstMakesNoBase(route shared: PhotoRenderRoute) async throws {
        var workspace = try Self.transforming()
        let route = Self.route(shared)
        let canvas = try #require(workspace.canvas)
        let tiles = PhotoRenderer.tiles(of: canvas, in: .all)
        let regions = route.isGPU ? Set(tiles.map(\.y)).count : tiles.count
        var shown = try await PhotoRenderer.update(workspace, since: nil, route: route)
        let opened = route.composites.made
        for _ in 1...2 {
            try Self.turned(&workspace, by: 5)
            shown = try await PhotoRenderer.update(workspace, since: shown.revision, route: route, live: true)
        }
        let settled = route.composites.made
        #expect(settled <= opened + 2 * regions, "the first two drag frames made more than the base under the Logo per region")
        for step in 3...5 {
            try Self.turned(&workspace, by: 5)
            let frame = try await PhotoRenderer.update(workspace, since: shown.revision, route: route, live: true)
            #expect(PhotoRenderRouteTests.laid(frame) != PhotoRenderRouteTests.laid(shown), "drag step \(step) drew the kept base as it was")
            shown = frame
        }
        #expect(route.composites.made == settled, "a later drag frame composited the layers under the Logo again")
    }
}

/// The live transform service with its whole-layer resamples counted.
final class CountingTransform: LayerTransforming {
    private let live = LiveTransform.make()
    private let count = Mutex(0)
    /// `applied` calls so far.
    var resamples: Int { count.withLock { $0 } }
    var unavailableHelp: String? { live.unavailableHelp }

    func handle(at point: Mask.Point, in draft: TransformDraft, tolerance: Double) -> TransformHandle? {
        live.handle(at: point, in: draft, tolerance: tolerance)
    }

    func dragged(_ draft: TransformDraft, handle: TransformHandle, from start: Mask.Point, to point: Mask.Point,
                 modifiers: DragModifiers) -> TransformDraft {
        live.dragged(draft, handle: handle, from: start, to: point, modifiers: modifiers)
    }

    func corners(of draft: TransformDraft) -> [Mask.Point] { live.corners(of: draft) }

    func applied(_ draft: TransformDraft, to content: PlacedPixels) throws -> PlacedPixels {
        count.withLock { $0 += 1 }
        return try live.applied(draft, to: content)
    }

    func flipped(_ content: PlacedPixels, _ axis: PhotoModel.FlipAxis) throws -> PlacedPixels { try live.flipped(content, axis) }

    func matrix(_ draft: TransformDraft, origin: (x: Int, y: Int)) throws -> AffineMatrix { try live.matrix(draft, origin: origin) }
}
