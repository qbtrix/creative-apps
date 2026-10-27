// PhotoRenderRouteTests.swift: the canvas through CoreRender's dispatcher
// draws exactly the CoreRaster reference. The document is Photo's layered
// fixture (the sample picture, a Curves adjustment layer and a Multiply stroke
// at 60 %) with exposure, levels, hue/saturation and blur on, so every branch
// of the route runs: composites, an adjustment layer and Hue/Saturation read
// back, the tone ops and the blur's margin. The GPU route's one-region path
// runs here on a second CPU backend as the preferred one, so it is held to
// the reference bit for bit on Linux; the Metal backend's parity is
// AppSnapshotTests' PhotoRenderBackendTests. Runs on Linux and macOS.
import CoreRaster
import CoreRender
import Testing

@testable import PhotoModel

@Suite struct PhotoRenderRouteTests {
    /// The layered fixture with every workspace adjustment on and away from its defaults.
    static func document() throws -> PhotoWorkspace {
        var workspace = try PhotoWorkspace.fixture(.layered)
        for edit: AdjustmentEdit in [
            .exposure(0.4), .blackPoint(0.05), .gamma(1.2), .hue(20), .saturation(15), .blurSigma(0.5),
        ] { workspace.adjust(edit) }
        return workspace
    }

    /// `update`'s tiles laid onto a canvas-sized picture, as the canvas lays its tile layers.
    static func laid(_ update: PhotoTileUpdate) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: update.width * update.height * 4)
        for tile in update.tiles {
            let r = tile.rect
            for row in 0..<r.height {
                let to = ((r.y + row) * update.width + r.x) * 4
                bytes.replaceSubrange(to..<(to + r.width * 4), with: tile.rgba8[(row * r.width * 4)...].prefix(r.width * 4))
            }
        }
        return bytes
    }

    /// A healthy stand-in for the GPU: CoreRender's CPU backend under another name.
    static let standIn = PhotoRenderRoute(preferred: CPUBackend(name: "stand-in"))

    @Test(arguments: [PhotoRenderRoute.cpu, standIn])
    func aFullUpdateThroughTheRouteIsTheReference(route: PhotoRenderRoute) async throws {
        let workspace = try Self.document()
        let update = try await PhotoRenderer.update(workspace, since: nil, route: route)
        let reference = try await PhotoRenderer.render(workspace)
        #expect(update.isComplete)
        #expect(Self.laid(update) == PhotoRenderer.premultiplied(reference.rgba8))
        #expect(update.backend == (route.preferred?.name ?? "cpu"))
    }

    @Test(arguments: [PhotoRenderRoute.cpu, standIn])
    func aStrokesDamagedTilesThroughTheRouteAreTheReference(route: PhotoRenderRoute) async throws {
        var workspace = try Self.document()
        let before = try await PhotoRenderer.update(workspace, since: nil, route: route)
        workspace.selectLayer(try #require(workspace.layers.last?.id))
        workspace.selectTool(.brush)
        workspace.drag(from: Mask.Point(x: 300, y: 280), to: Mask.Point(x: 300, y: 280))
        workspace.drag(from: Mask.Point(x: 300, y: 280), to: Mask.Point(x: 540, y: 330))
        let update = try await PhotoRenderer.update(workspace, since: before.revision, route: route)
        let canvas = try #require(workspace.canvas)
        #expect(!update.isComplete)
        #expect(Set(update.tiles.map(\.rect)) == Set(PhotoRenderer.tiles(of: canvas, in: workspace.damage(since: before.revision))))
        let reference = PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8)
        for tile in update.tiles {
            for row in 0..<tile.rect.height {
                let from = ((tile.rect.y + row) * canvas.width + tile.rect.x) * 4
                #expect(tile.rgba8[(row * tile.rect.width * 4)...].prefix(tile.rect.width * 4)
                    == reference[from..<(from + tile.rect.width * 4)])
            }
        }
    }

    @Test func aRegionsSurfaceIsTheRenderedRegion() throws {
        let workspace = try Self.document()
        let dispatcher = PhotoRenderRoute.cpu.dispatcher()
        let rect = PixelRect(x: 240, y: 200, width: 120, height: 90)
        let surface = try workspace.renderedSurface(rect, on: dispatcher)
        #expect(try dispatcher.read(surface) == workspace.rendered(rect))
    }

    @Test func onlyAHealthyPreferredBackendTakesTheRegionPath() {
        #expect(!PhotoRenderRoute.cpu.isGPU)
        #expect(Self.standIn.isGPU)
        let lost = FakeBackend(name: "lost", supports: Set(RenderOp.allCases), healthy: false)
        #expect(!PhotoRenderRoute(preferred: lost).isGPU)
    }

    /// A Move of the top layer (Paint), step after step, on a route with a cache of its own: the open's render
    /// keeps every region whole; the first step makes the base under the moved layer once per region; the next
    /// step lays the moved layer on that base and makes nothing; a slider step after it makes nothing either.
    /// The picture is the reference at the end.
    @Test(arguments: [PhotoRenderRoute.cpu, standIn])
    func aMoveStepLaysOnlyTheMovedLayerOnItsKeptBase(route shared: PhotoRenderRoute) async throws {
        var workspace = try Self.document()
        let route = PhotoRenderRoute(preferred: shared.preferred)
        let canvas = try #require(workspace.canvas)
        let tiles = PhotoRenderer.tiles(of: canvas, in: .all)
        // The CPU route composites a tile at a time, the GPU route a row of tiles.
        let regions = route.isGPU ? Set(tiles.map(\.y)).count : tiles.count
        let opened = try await PhotoRenderer.update(workspace, since: nil, route: route)
        #expect(route.composites.made == regions, "the open's render keeps every region whole")

        workspace.selectTool(.move)
        workspace.drag(from: Mask.Point(x: 100, y: 100), to: Mask.Point(x: 110, y: 104))
        let first = try await PhotoRenderer.update(workspace, since: opened.revision, route: route)
        #expect(route.composites.made == regions * 2, "the first step makes the base under the moved layer once per region")

        workspace.drag(from: Mask.Point(x: 110, y: 104), to: Mask.Point(x: 120, y: 110))
        let second = try await PhotoRenderer.update(workspace, since: first.revision, route: route)
        #expect(route.composites.made == regions * 2, "the next step composited the layers under the moved one again")
        workspace.endDrag()

        workspace.adjust(.gamma(1.4))
        let adjusted = try await PhotoRenderer.update(workspace, since: second.revision, route: route)
        #expect(route.composites.made == regions * 2, "a slider step composited the layers again")
        #expect(adjusted.isComplete)
        #expect(Self.laid(adjusted) == PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8))
    }
}
