// PhotoLiveMaskingTests.swift: a layer mask hides its layer on the live
// services, through every path that draws the canvas (#5196). The layered
// fixture's "Paint" stroke carries a mask that is white over its first two
// tile columns (x < 512) and black after, so the stroke shows at x 200 and is
// hidden at x 600: the CoreRaster reference, the dispatcher route (CPU and a
// stand-in GPU), and the resident and live-tone routes, which step aside for a
// masked layer. Runs on Linux and macOS.
import CoreRaster
import CoreRender
import Testing

@testable import PhotoModel

@Suite struct PhotoLiveMaskingTests {
    /// On the stroke, where the mask is white and where it is black.
    static let shown = (x: 200, y: 446), hidden = (x: 600, y: 374)

    /// The layered fixture on the live services, and its masked "Paint" layer.
    static func document() throws -> (PhotoWorkspace, PhotoLayer.ID) {
        var workspace = try PhotoWorkspace.fixture(.layered)
        workspace.services = .live
        let paint = try #require(workspace.layers.first { $0.hasMask }, "the sample's masked stroke layer")
        #expect(paint.isMaskEnabled && workspace.masks[paint.id] != nil)
        return (workspace, paint.id)
    }

    /// The display pixel at `p` of a full render through `route` (nil: the CoreRaster reference).
    static func pixel(_ workspace: PhotoWorkspace, _ p: (x: Int, y: Int), route: PhotoRenderRoute?) async throws
        -> ArraySlice<UInt8>
    {
        let canvas = try #require(workspace.canvas)
        let bytes: [UInt8]
        if let route {
            bytes = PhotoRenderRouteTests.laid(try await PhotoRenderer.update(workspace, since: nil, route: route))
        } else {
            bytes = PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8)
        }
        let at = (p.y * canvas.width + p.x) * 4
        return bytes[at..<(at + 4)]
    }

    @Test func theLiveMaskingIsBuilt() {
        #expect(PhotoServices.live.masking.unavailableHelp == nil)
    }

    @Test(arguments: [nil, PhotoRenderRoute.cpu, PhotoRenderRouteTests.standIn])
    func aBlackMaskHidesTheLayerAndAWhiteOneShowsIt(route: PhotoRenderRoute?) async throws {
        let (masked, id) = try Self.document()
        var without = masked
        without.toggleVisibility(id)
        let hiddenThere = try await Self.pixel(masked, Self.hidden, route: route)
        let shownThere = try await Self.pixel(masked, Self.shown, route: route)
        #expect(hiddenThere == (try await Self.pixel(without, Self.hidden, route: route)), "the black mask hides the stroke")
        #expect(shownThere != (try await Self.pixel(without, Self.shown, route: route)), "the white mask shows the stroke")
    }

    @Test func theResidentAndLiveToneRoutesStepAsideForAMaskedLayer() throws {
        var (workspace, id) = try Self.document()
        for layer in workspace.layers {
            if case .adjustment = layer.kind { workspace.toggleVisibility(layer.id) }  // the resident route's own fallback
        }
        workspace.adjust(.hue(-30))
        var plain = workspace
        plain.masks[id] = nil
        let gpu = CPUBackend(name: "stand-in"), resident = ResidentSurfaces(backend: gpu)
        let dispatcher = PhotoRenderRoute(preferred: gpu, resident: resident).dispatcher()
        let rect = PixelRect(x: 0, y: 0, width: 256, height: 256)
        #expect(try plain.residentComposited(rect, on: dispatcher, resident: resident) != nil)
        #expect(plain.liveStack() != nil)
        #expect(try workspace.residentComposited(rect, on: dispatcher, resident: resident) == nil)
        #expect(workspace.liveStack() == nil)
    }
}
