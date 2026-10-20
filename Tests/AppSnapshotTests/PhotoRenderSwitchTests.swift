// PhotoRenderSwitchTests.swift: what Photo's canvas holds on the GPU while View > Rendering moves between CPU
// and GPU and while windows close. The renderer keeps each layer's tiles resident on the Metal backend
// (ResidentSurfaces); the backend is one per process (PhotoRendering.shared), so tiles a renderer stops using
// must be released there, or every GPU -> CPU -> GPU round trip leaves a whole copy of the picture behind
// until the process runs out of memory and the canvas goes blank. Checked through the backend's
// `residentBytes`: flat across toggles, zero once the renderer is gone, and a large image toggled while its
// renders are still in flight draws the reference with no failure. macOS with a GPU only.
import AppKit
import Combine
import CoreRaster
import CoreRenderMetal
import Metal
import PhotoModel
import SuiteUI
import Testing

@testable import PhotoApp

@MainActor @Suite(.serialized) struct PhotoRenderSwitchTests {
    /// A host on the Metal path and a renderer attached to it, both following `preference`, the renderer onto `metal`.
    @MainActor final class Rig {
        let host = CanvasHostView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let presenter = CanvasTilePresenter()
        var renderer: CanvasRenderer? = CanvasRenderer()
        private var watch: AnyCancellable?
        /// The app holds its PhotoRendering for the process; the renderer only follows it weakly.
        let rendering: PhotoRendering

        init(_ preference: FakeRenderingPreference, metal: MetalBackend, show: @escaping @MainActor (CanvasRenderer) -> Void) {
            rendering = PhotoRendering(preference: preference, makeGPU: { metal })
            watch = host.follow(preference, device: MTLCreateSystemDefaultDevice(), presenter: presenter)
            guard let renderer else { return }
            renderer.tiles.attach(host)
            renderer.follow(rendering) { [weak renderer] in
                if let renderer { show(renderer) }
            }
        }
    }

    /// Waits up to 60 s for `renderer` to show `workspace`'s revision drawn by `backend`, with no render running
    /// or waiting: by then every tile set and composite a switch dropped has been released.
    static func drawn(_ renderer: CanvasRenderer, _ workspace: PhotoWorkspace, on backend: String) async throws {
        for _ in 0..<6000 where renderer.revision != workspace.revision || renderer.backend != backend || !renderer.isIdle {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(renderer.revision == workspace.revision && renderer.backend == backend && renderer.isIdle, "shows \(String(describing: renderer.revision)) of \(workspace.revision) on \(renderer.backend ?? "-"), wanted \(backend); \(renderer.failure ?? "no failure")")
        #expect(renderer.failure == nil, "\(renderer.failure ?? "")")
    }

    /// An opaque photo: `color` over the canvas with a lighter block, one pixel layer.
    static func photo(width: Int, height: Int, color: (UInt8, UInt8, UInt8)) throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: width, height: height)
        workspace.setToolOption(.color(red: color.0, green: color.1, blue: color.2))
        workspace.selectAll()
        workspace.fillSelection()
        workspace.setToolOption(.color(red: 240, green: 220, blue: 120))
        workspace.selectTool(.marquee)
        workspace.drag(from: Mask.Point(x: 40, y: 30), to: Mask.Point(x: 40, y: 30))
        workspace.drag(from: Mask.Point(x: 40, y: 30), to: Mask.Point(x: Double(width / 3), y: Double(height / 3)))
        workspace.endDrag()
        workspace.fillSelection()
        workspace.deselect()
        return workspace
    }

    /// The worst byte difference between the presenter's document texture and `workspace`'s premultiplied reference.
    static func worst(_ presenter: CanvasTilePresenter, _ workspace: PhotoWorkspace) async throws -> Int {
        let canvas = try #require(workspace.canvas)
        let texture = try #require(presenter.texture)
        try #require(texture.width == canvas.width && texture.height == canvas.height)
        var bytes = [UInt8](repeating: 0, count: canvas.width * canvas.height * 4)
        texture.getBytes(&bytes, bytesPerRow: canvas.width * 4, from: MTLRegionMake2D(0, 0, canvas.width, canvas.height), mipmapLevel: 0)
        let reference = PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8)
        return zip(bytes, reference).map { abs(Int($0) - Int($1)) }.max() ?? 255
    }

    @Test(.enabled(if: PhotoRenderBackendTests.device != nil)) func togglingTheBackendKeepsGPUMemoryFlat() async throws {
        let metal = try PhotoRenderBackendTests.metal()
        let preference = FakeRenderingPreference(choice: .gpu)
        var workspace = try Self.photo(width: 2000, height: 1500, color: (200, 30, 40))
        let rig = Rig(preference, metal: metal) { $0.show(workspace) }
        let renderer = try #require(rig.renderer)
        try await Self.drawn(renderer, workspace, on: metal.name)
        workspace.adjust(.exposure(0.1))
        renderer.show(workspace)
        try await Self.drawn(renderer, workspace, on: metal.name)
        let baseline = metal.residentBytes
        #expect(baseline > 0, "the layers never went resident")
        for round in 0..<4 {
            preference.set(.cpu)
            try await Self.drawn(renderer, workspace, on: "cpu")
            workspace.adjust(.gamma(1 + Float(round) / 10))
            renderer.show(workspace)
            preference.set(.gpu)
            try await Self.drawn(renderer, workspace, on: metal.name)
        }
        // A tile set the renderer dropped is released on the backend: a round trip leaves no copy behind.
        #expect(metal.residentBytes <= baseline, "GPU memory grew from \(baseline) to \(metal.residentBytes) bytes over 4 round trips")
        let worst = try await Self.worst(rig.presenter, workspace)
        #expect(worst <= 2, "the canvas differs from the picture by up to \(worst)")
    }

    @Test(.enabled(if: PhotoRenderBackendTests.device != nil)) func aClosedWindowsTilesLeaveTheGPU() async throws {
        let metal = try PhotoRenderBackendTests.metal()
        let preference = FakeRenderingPreference(choice: .gpu)
        let workspace = try Self.photo(width: 1200, height: 900, color: (20, 90, 230))
        let rig = Rig(preference, metal: metal) { $0.show(workspace) }
        try await Self.drawn(try #require(rig.renderer), workspace, on: metal.name)
        #expect(metal.residentBytes > 0)
        rig.renderer = nil
        for _ in 0..<1000 where metal.residentBytes > 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(metal.residentBytes == 0, "\(metal.residentBytes) bytes stayed on the GPU after the window's renderer went")
    }

    @Test(.enabled(if: PhotoRenderBackendTests.device != nil)) func aLargeImageToggledWhileRenderingStaysWholeAndBounded() async throws {
        let metal = try PhotoRenderBackendTests.metal()
        let preference = FakeRenderingPreference(choice: .cpu)
        // A 10K-wide file opens at Photo's 40 MP cap; this is a picture of that order, kept to debug test time.
        var workspace = try Self.photo(width: 4096, height: 3072, color: (120, 160, 60))
        let rig = Rig(preference, metal: metal) { $0.show(workspace) }
        let renderer = try #require(rig.renderer)
        try await Self.drawn(renderer, workspace, on: "cpu")
        preference.set(.gpu)
        try await Self.drawn(renderer, workspace, on: metal.name)
        // The switch's own frame may draw before the host's presenter exists (the two observers run in either
        // order), off the live route and so with no cached composite; an edit's frame draws on it for sure.
        workspace.adjust(.exposure(0.05))
        renderer.show(workspace)
        try await Self.drawn(renderer, workspace, on: metal.name)
        let baseline = metal.residentBytes
        // Edits and switches back to back: each switch lands while the render before it is still drawing.
        for step in 0..<8 {
            workspace.adjust(.exposure(Float(step) / 20))
            renderer.show(workspace)
            preference.set(step.isMultiple(of: 2) ? .cpu : .gpu)
            workspace.adjust(.saturation(Double(step) * 3))
            renderer.show(workspace, quietly: true)
        }
        preference.set(.gpu)
        try await Self.drawn(renderer, workspace, on: metal.name)
        // Idle, every set a switch dropped mid-render is gone: what is left is this route's tiles and composites.
        #expect(metal.residentBytes <= baseline + baseline / 4, "GPU memory went from \(baseline) to \(metal.residentBytes) bytes")
        let worst = try await Self.worst(rig.presenter, workspace)
        #expect(worst <= 2, "the canvas differs from the picture by up to \(worst)")
    }
}
