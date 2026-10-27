// PhotoLiveTransformTests.swift: Free Transform's draft is live on the canvas (#5279). While the draft is up,
// each render draws its layer through the draft, on the CPU route and the GPU's one-region route (a CPU
// backend standing in, held bit for bit): a move or turn step changes the picture before Return, Return lays
// exactly the last preview (which is also the reference render of the committed layer), Escape gives the
// picture back, and a step after the first makes no new base under the draft's layer (PhotoCompositeCache).
// The per-layer composite counts are IdleWorkTests' (AppSnapshotTests). Live transform services, so the
// preview is the real lanczos3 resample. Runs on Linux and macOS.
import CoreRaster
import CoreRender
import SuiteKernel
import Testing

@testable import PhotoModel

@Suite struct PhotoLiveTransformTests {
    /// A 300 x 200 white image, a 60 x 40 red "Logo" at (120, 80) and a translucent blue wash over everything;
    /// the Logo selected with Free Transform begun.
    static func transforming() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace(services: .live)
        try workspace.newCanvas(width: 300, height: 200)
        let red = TiledPixels(try PixelBuffer(width: 60, height: 40, fill: RGBA(r: 1, g: 0, b: 0, a: 1)))
        let logo = workspace.insertLayer(named: "Logo", pixels: red, kind: .pixels, at: 0)
        let at = try #require(workspace.index(of: logo))
        (workspace.layers[at].offsetX, workspace.layers[at].offsetY) = (120, 80)
        let blue = TiledPixels(try PixelBuffer(width: 300, height: 200, fill: RGBA(r: 0, g: 0, b: 0.3, a: 0.3)))
        _ = workspace.insertLayer(named: "Wash", pixels: blue, kind: .pixels, at: 0)
        workspace.selectLayer(logo)
        workspace.selectTool(.move)
        try workspace.beginTransform()
        return workspace
    }

    /// A fresh route on `shared`'s backend, so no other test's kept composites count here.
    static func route(_ shared: PhotoRenderRoute) -> PhotoRenderRoute { PhotoRenderRoute(preferred: shared.preferred) }

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
}
