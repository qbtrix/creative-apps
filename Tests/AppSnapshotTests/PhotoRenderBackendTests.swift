// PhotoRenderBackendTests.swift: Photo's canvas on the Metal backend, on this
// Mac's GPU (skipped without one). Parity: Photo's layered fixture rendered
// through the Metal route matches the CoreRaster reference, as the linear
// buffer (ParityHarness) and as the canvas's premultiplied tile bytes, with no
// op falling back to the CPU: the layers alone within CoreRender's standard
// tolerance, and with every workspace adjustment on too within the bounds
// `cases` gives and says why. Switching: a window's renderer
// following View > Rendering redraws the whole picture on the backend the new
// choice names, and back. The resident path (layer tiles kept on the GPU,
// the picture written into a texture) draws the reference within the
// standard tolerance and uploads no tile for an adjustment. The route a
// choice gives is plain logic, so it is checked without a GPU too. macOS only.
import CoreRaster
import CoreRender
import CoreRenderMetal
import Metal
import PhotoModel
import SuiteUI
import Testing

@testable import PhotoApp

@Suite struct PhotoRenderBackendTests {
    static let device = MetalBackend.defaultDevice

    /// A Metal backend whose pipelines compile on first use, so every family is in `supports` at once.
    static func metal() throws -> MetalBackend {
        try MetalBackend(device: #require(device), cacheURL: nil)
    }

    /// Photo's layered fixture; `adjusted` turns every workspace adjustment on, away from its defaults.
    static func document(adjusted: Bool = true) throws -> PhotoWorkspace {
        var workspace = try PhotoWorkspace.fixture(.layered)
        guard adjusted else { return workspace }
        for edit: AdjustmentEdit in [
            .exposure(0.4), .blackPoint(0.05), .gamma(1.2), .hue(20), .saturation(15), .blurSigma(1.5),
        ] { workspace.adjust(edit) }
        return workspace
    }

    /// The layers alone (two composites and the Curves layer) are held to CoreRender's per-op `standard`
    /// tolerance. With the five adjustments after them the chain is nine steps on half floats, and
    /// exposure lifts the sky above 1, where a half's step is about 1e-3: the display bytes still hold
    /// `standard` (2 levels); the linear bound is `nonSeparable`'s (4e-3), the looser one core has.
    static let cases: [(adjusted: Bool, tolerance: ParityTolerance)] = [
        (false, .standard), (true, ParityTolerance(bytes: ParityTolerance.standard.bytes, linear: ParityTolerance.nonSeparable.linear)),
    ]

    /// `update`'s tiles laid onto a canvas-sized picture.
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

    @Test(.enabled(if: device != nil), arguments: cases)
    func theMetalRouteMatchesTheReferenceWithinParity(adjusted: Bool, tolerance: ParityTolerance) async throws {
        let workspace = try Self.document(adjusted: adjusted)
        let canvas = try #require(workspace.canvas)
        let metal = try Self.metal()
        let route = PhotoRenderRoute(preferred: metal)
        let dispatcher = route.dispatcher()
        let surface = try workspace.renderedSurface(PixelRect(x: 0, y: 0, width: canvas.width, height: canvas.height), on: dispatcher)
        let parity = try ParityHarness.compare(workspace.composite(), dispatcher.read(surface), tolerance: tolerance)
        dispatcher.release(surface)
        // A GPU without every family (a CI VM's) falls back for those, and parity still holds.
        if metal.supports == Set(RenderOp.allCases) {
            #expect(dispatcher.lastFallback == nil, "fell back to the CPU: \(String(describing: dispatcher.lastFallback))")
        }
        #expect(parity.passed, "Metal against the reference: \(parity)")

        let cpu = try await PhotoRenderer.update(workspace, since: nil)
        let gpu = try await PhotoRenderer.update(workspace, since: nil, route: route)
        #expect(cpu.backend == "cpu" && gpu.backend == metal.name)
        let worst = zip(Self.laid(cpu), Self.laid(gpu)).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(worst <= Int(ParityTolerance.standard.bytes), "canvas bytes differ by up to \(worst)")
        print("PHOTO-PARITY \(canvas.width)x\(canvas.height) layered\(adjusted ? " + adjustments" : ""): \(parity); canvas bytes worst \(worst)")
    }

    @Test(.enabled(if: device != nil)) func theResidentPathDrawsTheReferenceIntoATextureAndUploadsOnlyChanges() async throws {
        var workspace = try Self.document()
        for layer in workspace.layers { if case .adjustment = layer.kind { workspace.toggleVisibility(layer.id) } }
        let canvas = try #require(workspace.canvas)
        let metal = try Self.metal()
        let resident = ResidentSurfaces(backend: metal)
        let route = PhotoRenderRoute(preferred: metal, resident: resident)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: canvas.width, height: canvas.height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try #require(metal.device.makeTexture(descriptor: descriptor))
        let held = UncheckedTexture(texture: texture)
        let target = PhotoDisplayTarget { surface, rect in
            try metal.display(surface, into: held.texture, x: rect.x, y: rect.y, colorSpace: .sRGB, premultiplied: true)
        }
        let first = try await PhotoRenderer.update(workspace, since: nil, route: route, target: target)
        #expect(first.wroteTarget && first.tiles.isEmpty)
        let uploads = resident.uploads
        #expect(uploads > 0)
        var bytes = [UInt8](repeating: 0, count: canvas.width * canvas.height * 4)
        texture.getBytes(&bytes, bytesPerRow: canvas.width * 4, from: MTLRegionMake2D(0, 0, canvas.width, canvas.height), mipmapLevel: 0)
        let reference = PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8)
        let worst = zip(bytes, reference).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(worst <= Int(ParityTolerance.standard.bytes), "texture bytes differ from the reference by up to \(worst)")
        workspace.adjust(.exposure(0.6))
        _ = try await PhotoRenderer.update(workspace, since: first.revision, route: route, target: target)
        #expect(resident.uploads == uploads, "an adjustment uploaded layer tiles")
        print("PHOTO-RESIDENT-PARITY \(canvas.width)x\(canvas.height): texture bytes worst \(worst), \(uploads) tiles uploaded once")
    }

    @MainActor @Test(.enabled(if: device != nil)) func theLiveHostShowsTheResidentPictureInThePresentersTexture() async throws {
        var workspace = try Self.document()
        for layer in workspace.layers { if case .adjustment = layer.kind { workspace.toggleVisibility(layer.id) } }
        let canvas = try #require(workspace.canvas)
        // As the app wires it: the host on the system device, the backend on MetalBackend.defaultDevice.
        let host = CanvasHostView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let presenter = CanvasTilePresenter()
        host.useRendering(.gpu, device: MTLCreateSystemDefaultDevice(), presenter: presenter)
        let renderer = CanvasRenderer()
        renderer.tiles.attach(host)
        renderer.use(PhotoRenderRoute(preferred: try Self.metal()))
        renderer.show(workspace)
        for _ in 0..<600 where renderer.revision != workspace.revision { try await Task.sleep(for: .milliseconds(20)) }
        #expect(renderer.revision == workspace.revision, "\(renderer.failure ?? "the picture never landed")")
        host.layoutSubtreeIfNeeded()
        // The resident path drew it: layer tiles went up once, and no tile bytes came back to the canvas.
        #expect((renderer.route.residentTiles?.uploads ?? 0) > 0)
        #expect(renderer.tiles.images.isEmpty, "tile bytes came back on the resident path")
        let texture = try #require(presenter.texture)
        #expect(texture.width == canvas.width && texture.height == canvas.height)
        var bytes = [UInt8](repeating: 0, count: canvas.width * canvas.height * 4)
        texture.getBytes(&bytes, bytesPerRow: canvas.width * 4, from: MTLRegionMake2D(0, 0, canvas.width, canvas.height), mipmapLevel: 0)
        let reference = PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8)
        let worst = zip(bytes, reference).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(worst <= Int(ParityTolerance.standard.bytes), "the presenter's texture differs from the reference by up to \(worst)")
    }

    @MainActor @Test(.enabled(if: device != nil)) func switchingTheChoiceRedrawsOnTheNewBackend() async throws {
        let preference = FakeRenderingPreference(choice: .cpu)
        let metal = try Self.metal()
        let rendering = PhotoRendering(preference: preference, makeGPU: { metal })
        let workspace = try PhotoWorkspace.fixture(.layered)
        let canvas = try #require(workspace.canvas)
        let renderer = CanvasRenderer()
        renderer.follow(rendering) { renderer.show(workspace) }
        try await drawn(by: "cpu", renderer)
        for (choice, backend) in [(RenderingChoice.gpu, metal.name), (.cpu, "cpu"), (.automatic, metal.name)] {
            preference.set(choice)
            try await drawn(by: backend, renderer)
            // The whole picture, not a revision's damage: every tile came again from the new backend.
            #expect(renderer.tiles.handedBytes == canvas.width * canvas.height * 4, "\(choice)")
            #expect(renderer.revision == workspace.revision)
        }
    }

    @Test func theRouteFollowsTheChoiceAndTheGPUsHealth() {
        let healthy = FakeBackend(name: "Metal (fake)", supports: Set(RenderOp.allCases))
        let lost = FakeBackend(name: "Metal (lost)", supports: Set(RenderOp.allCases), healthy: false)
        #expect(PhotoRendering.route(.cpu, gpu: healthy).preferred == nil)
        #expect(PhotoRendering.route(.gpu, gpu: healthy).preferred?.name == healthy.name)
        #expect(PhotoRendering.route(.automatic, gpu: healthy).preferred?.name == healthy.name)
        #expect(PhotoRendering.route(.automatic, gpu: lost).preferred == nil)
        #expect(PhotoRendering.route(.gpu, gpu: nil).preferred == nil)
    }

    @Test func theStatusLineNamesTheBackendThatDrew() {
        #expect(PhotoStatusLine.renderText(12.4, backend: nil) == "12 ms render")
        #expect(PhotoStatusLine.renderText(40, backend: "cpu") == "CPU · 40 ms render")
        #expect(PhotoStatusLine.renderText(7.6, backend: "Metal (Apple M2 Pro)") == "GPU (Metal) · 8 ms render")
    }

    /// Waits up to 10 s for a picture drawn by `backend`.
    @MainActor private func drawn(by backend: String, _ renderer: CanvasRenderer) async throws {
        for _ in 0..<2000 where renderer.backend != backend { try await Task.sleep(for: .milliseconds(5)) }
        #expect(renderer.backend == backend && renderer.failure == nil, "\(renderer.failure ?? "")")
    }
}

/// A texture the display target's closure carries across tasks; Metal textures are thread-safe.
private struct UncheckedTexture: @unchecked Sendable {
    let texture: any MTLTexture
}
