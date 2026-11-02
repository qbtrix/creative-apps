// PhotoLiveToneTests.swift: the live route (PhotoLiveTone.swift) on the resident GPU route with a target that
// runs tone programs. A whole-image slider step (levels, curves, Photo's hue/saturation matrix) gives the
// CoreRaster reference within 2 display levels and composites nothing after the first picture; an adjustment
// layer at the top, one under a pixel layer, and one at 50 % Multiply all take the live route (layer tiles stay
// resident, nothing read back) and give the reference, and a step on the top or middle layer composites
// nothing either; Blur sends a region back to the dispatcher route; a Free Transform drag frame keeps its base
// under the draft's layer and draws that layer through its matrix, the same bytes as the dispatcher route's frame.
// The "GPU" is CoreRender's CPU backend under another name (it runs tone programs through ToneProgram.map), so
// it all runs on Linux.
import CoreRaster
import CoreRender
import Foundation
import SuiteKernel
import Testing

@testable import PhotoModel

/// A canvas-sized picture the target writes regions into, the tone program applied on the way as Metal's
/// `display_tone` applies it.
private final class TonedSink: @unchecked Sendable {
    let backend: CPUBackend
    let width: Int
    private let lock = NSLock()
    private(set) var bytes: [UInt8]
    private(set) var toned = 0

    init(backend: CPUBackend, width: Int, height: Int) {
        (self.backend, self.width, bytes) = (backend, width, [UInt8](repeating: 0, count: width * height * 4))
    }

    var target: PhotoDisplayTarget {
        PhotoDisplayTarget(
            write: { [self] surface, rect in try put(surface, rect, toned: false) },
            writeToned: { [self] surface, rect, tone in
                let adjusted = try backend.adjusted(surface, tone: tone)
                defer { backend.release(adjusted) }
                try put(adjusted, rect, toned: true)
            })
    }

    private func put(_ surface: RenderSurface, _ rect: PixelRect, toned: Bool) throws {
        let encoded = PhotoRenderer.premultiplied(try backend.display(surface, colorSpace: .sRGB))
        lock.lock()
        defer { lock.unlock() }
        if toned { self.toned += 1 }
        for row in 0..<rect.height {
            let to = ((rect.y + row) * width + rect.x) * 4
            bytes.replaceSubrange(to..<(to + rect.width * 4), with: encoded[(row * rect.width * 4)...].prefix(rect.width * 4))
        }
    }
}

@Suite struct PhotoLiveToneTests {
    /// A Free Transform drag frame on the top (screened) layer under a hue slider: the live route's base ends
    /// under the draft's layer, so the frame changes the picture and equals the dispatcher route's drag frame,
    /// and a later frame composites nothing under it.
    @Test func aTransformDragFrameTakesTheLiveRouteUnderTheDraft() async throws {
        var workspace = try Self.document()
        workspace.adjust(.hue(-30))
        workspace.selectLayer(try #require(workspace.layers.first?.id))
        workspace.selectTool(.select)
        try workspace.beginTransform()
        let canvas = try #require(workspace.canvas)
        let (route, _, gpu) = Self.route()
        let sink = TonedSink(backend: gpu, width: canvas.width, height: canvas.height)
        let opened = try await PhotoRenderer.update(workspace, since: nil, route: route, target: sink.target)
        let before = sink.bytes
        let box = try #require(workspace.transformSelection)
        try workspace.setTransform(SuiteKernel.TransformRules.rotated(box, by: 10), name: "Rotate", drag: "turn")
        let first = try await PhotoRenderer.update(workspace, since: opened.revision, route: route, target: sink.target, live: true)
        #expect(first.liveDraft)
        #expect(sink.bytes != before, "the drag frame left the picture as it was")
        // The dispatcher route's drag frame of the same workspace, byte for byte: one matrix, one composite.
        let plain = PhotoRenderRoute(preferred: CPUBackend(name: "plain"))
        let frame = try await PhotoRenderer.update(workspace, since: nil, route: plain, live: true)
        let laid = PhotoRenderRouteTests.laid(frame)
        let worst = zip(sink.bytes, laid).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(worst <= 2, "the live route's drag frame differs from the dispatcher route's by \(worst) levels")
        let made = route.composites.made
        try workspace.setTransform(SuiteKernel.TransformRules.rotated(box, by: 20), name: "Rotate", drag: "turn")
        _ = try await PhotoRenderer.update(workspace, since: first.revision, route: route, target: sink.target, live: true)
        #expect(route.composites.made == made, "a later drag frame composited the layers under the draft again")
    }

    /// 600 x 400 (six tiles): a white Background with a red block, and a blue block screened at 60 % on top.
    static func document() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 600, height: 400)
        fill(&workspace, red: 200, green: 30, blue: 40, from: Mask.Point(x: 20, y: 30), to: Mask.Point(x: 380, y: 300))
        workspace.addLayer()
        fill(&workspace, red: 20, green: 90, blue: 230, from: Mask.Point(x: 200, y: 60), to: Mask.Point(x: 560, y: 380))
        let top = try #require(workspace.selectedLayerID)
        workspace.setBlendMode(top, .screen)
        workspace.setOpacity(top, percent: 60)
        return workspace
    }

    static func fill(_ workspace: inout PhotoWorkspace, red: UInt8, green: UInt8, blue: UInt8, from a: Mask.Point, to b: Mask.Point) {
        workspace.setToolOption(.color(red: red, green: green, blue: blue))
        workspace.selectTool(.marquee)
        workspace.drag(from: a, to: a)
        workspace.drag(from: a, to: b)
        workspace.endDrag()
        workspace.fillSelection()
        workspace.deselect()
    }

    static func route() -> (PhotoRenderRoute, ResidentSurfaces, CPUBackend) {
        let gpu = CPUBackend(name: "stand-in")
        let resident = ResidentSurfaces(backend: gpu)
        return (PhotoRenderRoute(preferred: gpu, resident: resident), resident, gpu)
    }

    /// The largest byte difference between `bytes` and the CoreRaster reference of `workspace`.
    static func worst(_ bytes: [UInt8], _ workspace: PhotoWorkspace) async throws -> Int {
        let reference = PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8)
        return zip(bytes, reference).map { abs(Int($0) - Int($1)) }.max() ?? 0
    }

    @Test func aWholeImageSliderStepIsTheReferenceAndCompositesNothing() async throws {
        var workspace = try Self.document()
        for edit: AdjustmentEdit in [.exposure(0.3), .blackPoint(0.04), .gamma(1.3), .hue(25), .saturation(-20), .lightness(10),
                                     .curvePoints([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.5, y: 0.6), CurvePoint(x: 1, y: 1)])] {
            workspace.adjust(edit)
        }
        let canvas = try #require(workspace.canvas)
        let (route, resident, gpu) = Self.route()
        let sink = TonedSink(backend: gpu, width: canvas.width, height: canvas.height)
        let first = try await PhotoRenderer.update(workspace, since: nil, route: route, target: sink.target)
        #expect(sink.toned > 0, "the regions went through the tone program")
        #expect(try await Self.worst(sink.bytes, workspace) <= 2)
        let (uploads, made) = (resident.uploads, route.composites.made)
        workspace.adjust(.gamma(1.5))
        workspace.adjust(.saturation(30))
        _ = try await PhotoRenderer.update(workspace, since: first.revision, route: route, target: sink.target)
        #expect(resident.uploads == uploads, "a slider step uploaded layer tiles")
        #expect(route.composites.made == made, "a slider step composited the layers again")
        #expect(try await Self.worst(sink.bytes, workspace) <= 2)
    }

    @Test(arguments: [0, 1, 2])
    func anAdjustmentLayerTakesTheLiveRouteAndIsTheReference(at position: Int) async throws {
        var workspace = try Self.document()
        // 0: on top; 1: under the screened layer; 2: on top at 50 % Multiply.
        workspace.selectLayer(try #require(position == 1 ? workspace.layers.last?.id : workspace.layers.first?.id))
        workspace.addAdjustmentLayer(.levels)
        let id = try #require(workspace.selectedLayerID)
        workspace.adjustLayer(id, .gamma(1.6))
        workspace.adjustLayer(id, .whitePoint(0.85))
        if position == 2 {
            workspace.setBlendMode(id, .multiply)
            workspace.setOpacity(id, percent: 50)
        }
        workspace.adjust(.hue(-30))
        let canvas = try #require(workspace.canvas)
        let (route, resident, gpu) = Self.route()
        let sink = TonedSink(backend: gpu, width: canvas.width, height: canvas.height)
        let first = try await PhotoRenderer.update(workspace, since: nil, route: route, target: sink.target)
        #expect(resident.uploads > 0, "the layers stayed resident: the live route, not the old path")
        #expect(try await Self.worst(sink.bytes, workspace) <= 2, "position \(position)")
        let made = route.composites.made
        workspace.adjustLayer(id, .gamma(1.2))
        _ = try await PhotoRenderer.update(workspace, since: first.revision, route: route, target: sink.target)
        #expect(route.composites.made == made, "a step on the layer composited the layers under it again")
        #expect(try await Self.worst(sink.bytes, workspace) <= 2, "position \(position) after a step")
    }

    @Test func blurTakesTheDispatcherRoute() async throws {
        var workspace = try Self.document()
        workspace.adjust(.blurSigma(1))
        #expect(workspace.liveStack() == nil)
        let canvas = try #require(workspace.canvas)
        let (route, _, gpu) = Self.route()
        let sink = TonedSink(backend: gpu, width: canvas.width, height: canvas.height)
        _ = try await PhotoRenderer.update(workspace, since: nil, route: route, target: sink.target)
        #expect(sink.toned == 0)
        #expect(try await Self.worst(sink.bytes, workspace) <= 1)
    }
}
