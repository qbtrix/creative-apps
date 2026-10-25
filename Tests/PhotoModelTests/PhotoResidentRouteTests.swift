// PhotoResidentRouteTests.swift: the GPU route with resident layer tiles. A
// render composites from ResidentSurfaces and writes each damaged region to a
// PhotoDisplayTarget, and the picture is the CoreRaster reference bit for bit;
// a second render with nothing changed uploads no tile, a dab inside one tile
// uploads exactly that one; an adjustment layer takes the old path and still
// gives the reference. The "GPU" is CoreRender's CPU backend under another
// name, as PhotoRenderRouteTests' stand-in, so it all runs on Linux.
import CoreRaster
import CoreRender
import Foundation
import Testing

@testable import PhotoModel

/// A canvas-sized picture the target writes regions into, as the presenter's texture takes them.
private final class Sink: @unchecked Sendable {
    let backend: CPUBackend
    let width: Int
    private let lock = NSLock()
    private(set) var bytes: [UInt8]
    private(set) var regions = 0

    init(backend: CPUBackend, width: Int, height: Int) {
        (self.backend, self.width, bytes) = (backend, width, [UInt8](repeating: 0, count: width * height * 4))
    }

    var target: PhotoDisplayTarget {
        PhotoDisplayTarget { [self] surface, rect in
            let encoded = PhotoRenderer.premultiplied(try backend.display(surface, colorSpace: .sRGB))
            lock.lock()
            defer { lock.unlock() }
            regions += 1
            for row in 0..<rect.height {
                let to = ((rect.y + row) * width + rect.x) * 4
                bytes.replaceSubrange(to..<(to + rect.width * 4), with: encoded[(row * rect.width * 4)...].prefix(rect.width * 4))
            }
        }
    }
}

@Suite struct PhotoResidentRouteTests {
    /// PhotoRenderRouteTests' document with its adjustment layer hidden and its mask dropped, so every visible
    /// layer is unmasked pixels (a masked layer takes the dispatcher route, PhotoLiveMaskingTests).
    static func document() throws -> PhotoWorkspace {
        var workspace = try PhotoRenderRouteTests.document()
        for layer in workspace.layers {
            if case .adjustment = layer.kind { workspace.toggleVisibility(layer.id) }
            workspace.masks[layer.id] = nil
        }
        return workspace
    }

    static func route() -> (PhotoRenderRoute, ResidentSurfaces, CPUBackend) {
        let gpu = CPUBackend(name: "stand-in")
        let resident = ResidentSurfaces(backend: gpu)
        return (PhotoRenderRoute(preferred: gpu, resident: resident), resident, gpu)
    }

    @Test func aResidentRenderWritesTheReferenceToTheTarget() async throws {
        let workspace = try Self.document()
        let canvas = try #require(workspace.canvas)
        let (route, resident, gpu) = Self.route()
        let sink = Sink(backend: gpu, width: canvas.width, height: canvas.height)
        let update = try await PhotoRenderer.update(workspace, since: nil, route: route, target: sink.target)
        #expect(update.wroteTarget && update.tiles.isEmpty && update.isComplete)
        #expect(resident.uploads > 0)
        #expect(sink.bytes == PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8))
    }

    @Test func anUnchangedRenderUploadsNothingAndADabUploadsItsOneTile() async throws {
        var workspace = try Self.document()
        let canvas = try #require(workspace.canvas)
        let (route, resident, gpu) = Self.route()
        let sink = Sink(backend: gpu, width: canvas.width, height: canvas.height)
        let first = try await PhotoRenderer.update(workspace, since: nil, route: route, target: sink.target)
        let uploaded = resident.uploads
        _ = try await PhotoRenderer.update(workspace, since: nil, route: route, target: sink.target)
        #expect(resident.uploads == uploaded, "a render with nothing changed uploaded tiles")

        workspace.selectLayer(try #require(workspace.layers.last?.id))
        workspace.selectTool(.brush)
        workspace.setToolOption(.size(8))
        workspace.drag(from: Mask.Point(x: 100, y: 100), to: Mask.Point(x: 100, y: 100))
        workspace.endDrag()
        let dab = try await PhotoRenderer.update(workspace, since: first.revision, route: route, target: sink.target)
        #expect(!dab.isComplete)
        #expect(resident.uploads == uploaded + 1, "a dab inside one tile uploaded \(resident.uploads - uploaded)")
        #expect(sink.bytes == PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8))
    }

    @Test func anAdjustmentLayerTakesTheOldPathAndStillGivesTheReference() async throws {
        let workspace = try PhotoRenderRouteTests.document()
        let canvas = try #require(workspace.canvas)
        let (route, resident, gpu) = Self.route()
        let sink = Sink(backend: gpu, width: canvas.width, height: canvas.height)
        _ = try await PhotoRenderer.update(workspace, since: nil, route: route, target: sink.target)
        #expect(resident.uploads == 0)
        #expect(sink.bytes == PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8))
    }

    @Test func aBackendWithoutTheBlendFamiliesKeepsNoResidentTiles() {
        let fake = FakeBackend(name: "fake", supports: [.composite, .display])
        #expect(PhotoRenderRoute(preferred: fake, resident: ResidentSurfaces(backend: fake)).residentTiles == nil)
        let gpu = CPUBackend(name: "stand-in")
        #expect(PhotoRenderRoute(preferred: gpu, resident: ResidentSurfaces(backend: CPUBackend(name: "other"))).residentTiles == nil)
        #expect(PhotoRenderRoute(preferred: gpu, resident: ResidentSurfaces(backend: gpu)).residentTiles != nil)
    }
}
