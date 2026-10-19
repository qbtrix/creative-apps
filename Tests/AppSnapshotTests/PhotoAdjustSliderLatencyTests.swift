// PhotoAdjustSliderLatencyTests.swift: how long one adjustment-slider step on an 8K document (7680 x 4320,
// PhotoRenderBudgetTests' three layers) takes from the value changing to the canvas texture holding the new
// picture, done the way the window does it: the edit mutates the workspace (`adjust`, or `adjustLayer` for an
// adjustment layer), then PhotoRenderer.update draws what it damaged through the route the canvas renderer
// uses. On the GPU that is Metal with resident layer tiles writing into a canvas-sized texture (the presenter's);
// on the CPU, CoreRender's CPU backend returning tile bytes. Cases: Hue/Saturation's Saturation, Levels' Gamma,
// Curves' midpoint, a Levels and a Hue/Saturation adjustment layer at the top of the stack, and the Move tool
// dragging the top layer 3 px a step (also a whole-canvas redraw that changes no tile's pixels). Each case warms
// with a full picture and one untimed step, then times `events` steps. The target is p95 <= 16 ms per step at
// 8K on the GPU route (one display frame); a step over it is a known issue until the GPU tone pass lands.
// `breakdown` splits one GPU step into its phases (the composite of the layers, each adjustment, the write into
// the texture), band by band one after another, to show where a step's time goes. Report-only
// (Tests/perf-suites.txt): ADJUST-SLIDER-8K and ADJUST-BREAKDOWN-8K lines in
// .build/snapshots/photo-adjust-slider-latency.txt. Read release numbers: a debug build is 20x slower.
// macOS only.
import CoreRaster
import CoreRender
import CoreRenderMetal
import Foundation
import Metal
import Testing

@testable import PhotoModel

@Suite(.serialized) struct PhotoAdjustSliderLatencyTests {
    static let config = PhotoRenderBudgetTests.config
    static let events = config == "release" ? 30 : 3
    /// One display frame at 60 Hz: the GPU route's target per step.
    static let target = 16.0

    /// A case: its name, how it sets the document up (returns the adjustment layer's id, if any), and step `i`
    /// (an adjustment edit, or a Move tool drag sample).
    struct Case: Sendable {
        let name: String
        let setUp: @Sendable (inout PhotoWorkspace) throws -> PhotoLayer.ID?
        let step: @Sendable (inout PhotoWorkspace, PhotoLayer.ID?, Int) -> Void

        init(name: String, setUp: @escaping @Sendable (inout PhotoWorkspace) throws -> PhotoLayer.ID? = { _ in nil },
             edit: @escaping @Sendable (Int) -> AdjustmentEdit) {
            self.name = name
            self.setUp = setUp
            step = { workspace, layer, i in PhotoAdjustSliderLatencyTests.apply(edit(i), layer: layer, to: &workspace) }
        }

        init(name: String, setUp: @escaping @Sendable (inout PhotoWorkspace) throws -> PhotoLayer.ID?,
             step: @escaping @Sendable (inout PhotoWorkspace, PhotoLayer.ID?, Int) -> Void) {
            (self.name, self.setUp, self.step) = (name, setUp, step)
        }
    }

    static let cases: [Case] = [
        Case(name: "hue-sat saturation", edit: { .saturation(-40 + Double($0)) }),
        Case(name: "levels gamma", edit: { .gamma(1.2 + Float($0) * 0.01) }),
        Case(name: "curves midpoint", edit: { i in
            .curvePoints([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.5, y: 0.55 + Float(i) * 0.005), CurvePoint(x: 1, y: 1)])
        }),
        Case(name: "levels layer gamma", setUp: { try layer(.levels, in: &$0) }, edit: { .gamma(1.2 + Float($0) * 0.01) }),
        Case(name: "hue-sat layer saturation", setUp: { try layer(.hueSaturation, in: &$0) },
             edit: { .saturation(-40 + Double($0)) }),
        // The Move tool on the top layer (one brush stroke), 3 px a step.
        Case(name: "move layer", setUp: { workspace in
            workspace.selectLayer(try #require(workspace.layers.first?.id))
            workspace.selectTool(.move)
            return nil
        }, step: { workspace, _, i in
            workspace.drag(from: Mask.Point(x: 2000, y: 2000), to: Mask.Point(x: 2000 + Double(i * 3), y: 2000 + Double(i)))
        }),
    ]

    /// An adjustment layer of `kind` added above the selected (top) layer.
    static func layer(_ kind: AdjustmentKind, in workspace: inout PhotoWorkspace) throws -> PhotoLayer.ID? {
        workspace.selectLayer(try #require(workspace.layers.first?.id))
        workspace.addAdjustmentLayer(kind)
        return try #require(workspace.selectedLayerID)
    }

    static func apply(_ edit: AdjustmentEdit, layer: PhotoLayer.ID?, to workspace: inout PhotoWorkspace) {
        if let layer { workspace.adjustLayer(layer, edit) } else { workspace.adjust(edit) }
    }

    /// The canvas renderer's GPU route (resident tiles) and a texture target, or nil without a GPU.
    static func gpu() throws -> (MetalBackend, PhotoRenderRoute, PhotoDisplayTarget)? {
        guard let device = MetalBackend.defaultDevice else { return nil }
        let metal = try MetalBackend(device: device, cacheURL: nil)
        let route = PhotoRenderRoute(preferred: metal, resident: ResidentSurfaces(backend: metal))
        return (metal, route, try PhotoRenderBudgetTests.textureTarget(metal, width: 7680, height: 4320))
    }

    @Test(.timeLimit(.minutes(30))) func eightKSliderStepOnEachRoute() async throws {
        var routes: [(String, () throws -> (PhotoRenderRoute, PhotoDisplayTarget?))] = [("CPU", { (.cpu, nil) })]
        if MetalBackend.defaultDevice != nil {
            routes.insert(("GPU-resident", { let (_, route, target) = try #require(try Self.gpu()); return (route, target) }), at: 0)
        }
        var lines: [String] = []
        var misses: [String] = []
        for (label, make) in routes {
            for slider in Self.cases {
                let (route, target) = try make()
                var workspace = try PhotoRenderBudgetTests.document()
                let layer = try slider.setUp(&workspace)
                var shown = try await PhotoRenderer.update(workspace, since: nil, route: route, target: target).revision
                var steps: [Double] = []
                for i in 0...Self.events {
                    let clock = ContinuousClock()
                    let t0 = clock.now
                    slider.step(&workspace, layer, i)
                    let update = try await PhotoRenderer.update(workspace, since: shown, route: route, target: target)
                    let ms = milliseconds(clock.now - t0)
                    #expect(update.revision == workspace.revision)
                    shown = update.revision
                    if i > 0 { steps.append(ms) }  // the first step builds what the rest reuse
                }
                let p50 = percentile(steps, 0.5), p95 = percentile(steps, 0.95)
                let line = "ADJUST-SLIDER-8K \(label) \(Self.config) \(slider.name): p50 \(format(p50)) ms p95 \(format(p95)) ms max \(format(steps.max() ?? 0)) ms (\(steps.count) steps)"
                print(line)
                lines.append(line)
                if label == "GPU-resident", p95 > Self.target { misses.append(line) }
            }
        }
        lines += try await Self.breakdown()
        let folder = URL(fileURLWithPath: ".build/snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try (lines.joined(separator: "\n") + "\n").write(
            to: folder.appendingPathComponent("photo-adjust-slider-latency.txt"), atomically: true, encoding: .utf8)
        withKnownIssue("an 8K step recomposites every layer and runs the adjustments as separate passes (hue/sat on the CPU)", isIntermittent: true) {
            #expect(misses.isEmpty || Self.config != "release", "over \(Self.target) ms p95: \(misses)")
        }
    }

    /// One GPU step's phases, each band (a row of tiles) one after another: the layers' composite from
    /// resident tiles, each enabled adjustment section, and the display write into the texture. Hue/Saturation
    /// splits into its readback, its CPU pass and its upload.
    static func breakdown() async throws -> [String] {
        guard let (_, route, target) = try gpu() else { return [] }
        var lines: [String] = []
        for slider in [cases[0], cases[1], cases[3], cases[5]] {
            var workspace = try PhotoRenderBudgetTests.document()
            let layer = try slider.setUp(&workspace)
            slider.step(&workspace, layer, 0)
            _ = try await PhotoRenderer.update(workspace, since: nil, route: route, target: target)
            let canvas = try #require(workspace.canvas)
            let rects = PhotoRenderer.tiles(of: canvas, in: .all)
            let bands = Dictionary(grouping: rects, by: \.y).values.map { band in
                PixelRect(x: band.map(\.x).min()!, y: band[0].y, width: band.map(\.maxX).max()! - band.map(\.x).min()!,
                          height: band[0].height)
            }
            var phase: [String: Double] = [:]
            func timed<T>(_ name: String, _ body: () throws -> T) rethrows -> T {
                let clock = ContinuousClock(), t0 = clock.now
                defer { phase[name, default: 0] += milliseconds(clock.now - t0) }
                return try body()
            }
            let settings = workspace.adjustments
            let clock = ContinuousClock(), t0 = clock.now
            for area in bands {
                let dispatcher = route.dispatcher()
                var picture = try timed("composite") {
                    if let resident = try workspace.residentComposited(area, on: dispatcher, resident: try #require(route.residentTiles)) {
                        return resident
                    }
                    return try workspace.composited(area, on: dispatcher)
                }
                func step(_ name: String, _ next: () throws -> RenderSurface) throws {
                    let made = try timed(name, next)
                    dispatcher.release(picture)
                    picture = made
                }
                if settings.isEnabled(.levels), [settings.blackPoint, settings.whitePoint, settings.gamma] != [0, 1, 1] {
                    try step("levels") {
                        try dispatcher.adjusted(picture, .levels(inBlack: settings.blackPoint, inWhite: settings.whitePoint,
                                                                 gamma: settings.gamma, outBlack: 0, outWhite: 1, encoding: .sRGB))
                    }
                }
                if settings.isEnabled(.hueSaturation), settings.saturation != 0 || settings.hue != 0 || settings.lightness != 0 {
                    let read = try timed("hue-sat readback") { try dispatcher.read(picture) }
                    let shifted = try timed("hue-sat CPU") {
                        try read.hueSaturation(hue: Float(settings.hue), saturation: Float(settings.saturation),
                                               lightness: Float(settings.lightness))
                    }
                    try step("hue-sat upload") { try dispatcher.surface(shifted) }
                }
                try timed("display write") { try target.write(picture, area) }
                dispatcher.release(picture)
            }
            let total = milliseconds(clock.now - t0)
            let parts = phase.sorted { $0.value > $1.value }.map { "\($0.key) \(format($0.value))" }.joined(separator: ", ")
            let line = "ADJUST-BREAKDOWN-8K GPU-resident \(config) \(slider.name): \(bands.count) bands one after another, \(format(total)) ms: \(parts) ms"
            print(line)
            lines.append(line)
        }
        return lines
    }
}
