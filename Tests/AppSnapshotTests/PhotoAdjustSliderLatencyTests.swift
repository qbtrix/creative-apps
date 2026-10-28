// PhotoAdjustSliderLatencyTests.swift: how long one adjustment-slider step on an 8K document (7680 x 4320,
// PhotoRenderBudgetTests' three layers) takes from the value changing to the canvas texture holding the new
// picture, done the way the window does it: the edit mutates the workspace (`adjust`, or `adjustLayer` for an
// adjustment layer), then PhotoRenderer.update draws what it damaged through the route the canvas renderer
// uses. On the GPU that is Metal with resident layer tiles writing into a canvas-sized texture (the presenter's);
// on the CPU, CoreRender's CPU backend returning tile bytes. Cases: Hue/Saturation's Saturation, Levels' Gamma,
// Curves' midpoint, a Levels and a Hue/Saturation adjustment layer at the top of the stack, and the Move tool
// dragging the top layer 3 px a step (also a whole-canvas redraw that changes no tile's pixels), alone and under
// a Levels adjustment layer, and a Free Transform rotate drag on the Fill layer (the whole 8K canvas), 1 degree
// a step, rendered as drag frames (`live`: the draft through its matrix per region, no whole-layer resample). Each case warms
// with a full picture and one untimed step, then times `events` steps. The target is p95 <= 16 ms per step at
// 8K on the GPU route (one display frame): a step over it is a known issue; one over `budget` fails a release run.
// `breakdown` shows where one GPU step's time goes on the live route: the plan (tone programs), the composites
// it made again, and the step. Report-only
// (Tests/perf-suites.txt): ADJUST-SLIDER-8K and ADJUST-BREAKDOWN-8K lines in
// .build/snapshots/photo-adjust-slider-latency.txt. Read release numbers: a debug build is 20x slower.
// macOS only.
import CoreRaster
import CoreRender
import CoreRenderMetal
import Foundation
import Metal
import SuiteKernel
import Testing

@testable import PhotoModel

@Suite(.serialized) struct PhotoAdjustSliderLatencyTests {
    static let config = PhotoRenderBudgetTests.config
    static let events = config == "release" ? 30 : 3
    /// One display frame at 60 Hz: the GPU route's target per step.
    static let target = 16.0
    /// The GPU route's p95 budget per step in release, a little above what it measures (render-budgets.md):
    /// an adjustment step re-encodes the cached composite (12 to 24 ms measured), a Move step composites every
    /// layer again (33 ms p50, up to 69 ms p95 on a busy machine), and a Free Transform drag frame resamples the
    /// 33 MP layer on the CPU in chunks (308 ms p50, 416 ms p95 measured; no Metal affine kernel yet).
    static func budget(_ name: String) -> Double { name.hasPrefix("transform") ? 500 : name.hasPrefix("move") ? 80 : 30 }

    /// A case: its name, how it sets the document up (returns the adjustment layer's id, if any), and step `i`
    /// (an adjustment edit, or a Move tool drag sample).
    struct Case: Sendable {
        let name: String
        let setUp: @Sendable (inout PhotoWorkspace) throws -> PhotoLayer.ID?
        let step: @Sendable (inout PhotoWorkspace, PhotoLayer.ID?, Int) -> Void
        /// The steps are a drag's samples: each renders a drag frame (`PhotoRenderer.update(live: true)`).
        var live = false
        /// Steps to time; nil for the suite's `events`.
        var steps: Int? = nil

        init(name: String, setUp: @escaping @Sendable (inout PhotoWorkspace) throws -> PhotoLayer.ID? = { _ in nil },
             edit: @escaping @Sendable (Int) -> AdjustmentEdit) {
            self.name = name
            self.setUp = setUp
            step = { workspace, layer, i in PhotoAdjustSliderLatencyTests.apply(edit(i), layer: layer, to: &workspace) }
        }

        init(name: String, setUp: @escaping @Sendable (inout PhotoWorkspace) throws -> PhotoLayer.ID?,
             step: @escaping @Sendable (inout PhotoWorkspace, PhotoLayer.ID?, Int) -> Void, live: Bool = false,
             steps: Int? = nil) {
            (self.name, self.setUp, self.step, self.live, self.steps) = (name, setUp, step, live, steps)
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
        // The same Move with a Levels adjustment layer above the moved layer.
        Case(name: "move under levels layer", setUp: { workspace in
            _ = try layer(.levels, in: &workspace)
            workspace.selectLayer(workspace.layers[1].id)
            workspace.selectTool(.move)
            return nil
        }, step: { workspace, _, i in
            workspace.drag(from: Mask.Point(x: 2000, y: 2000), to: Mask.Point(x: 2000 + Double(i * 3), y: 2000 + Double(i)))
        }),
        // Free Transform on the Fill layer (the whole 8K canvas): a rotate drag's frames, 1 degree a step, 60 steps.
        Case(name: "transform turn drag", setUp: { workspace in
            workspace.selectLayer(workspace.layers[1].id)
            workspace.selectTool(.move)
            try workspace.beginTransform()
            return nil
        }, step: { workspace, _, _ in
            guard let box = workspace.transformSelection else { return }
            try? workspace.setTransform(TransformRules.rotated(box, by: 1), name: "Rotate", drag: "turn")
        }, live: true, steps: config == "release" ? 60 : nil),
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
        var misses: [String] = [], over: [String] = []
        for (label, make) in routes {
            for slider in Self.cases {
                let (route, target) = try make()
                var workspace = try PhotoRenderBudgetTests.document()
                let layer = try slider.setUp(&workspace)
                var shown = try await PhotoRenderer.update(workspace, since: nil, route: route, target: target).revision
                var steps: [Double] = []
                for i in 0...(slider.steps ?? Self.events) {
                    let clock = ContinuousClock()
                    let t0 = clock.now
                    slider.step(&workspace, layer, i)
                    let update = try await PhotoRenderer.update(workspace, since: shown, route: route, target: target, live: slider.live)
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
                if label == "GPU-resident", p95 > Self.budget(slider.name) { over.append(line) }
            }
        }
        lines += try await Self.breakdown()
        let folder = URL(fileURLWithPath: ".build/snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try (lines.joined(separator: "\n") + "\n").write(
            to: folder.appendingPathComponent("photo-adjust-slider-latency.txt"), atomically: true, encoding: .utf8)
        #expect(over.isEmpty || Self.config != "release", "over budget: \(over)")
        withKnownIssue("Levels and Curves build their tables on the CPU each step, and a Move composites every layer", isIntermittent: true) {
            #expect(misses.isEmpty || Self.config != "release", "over \(Self.target) ms p95: \(misses)")
        }
    }

    /// Where a GPU step's time goes on the live route, for each case: building its plan (`liveStack`, whose
    /// tone programs probe the CPU for their tables), the composites it had to make again (the cache's
    /// misses: 0 for a slider, every band for a Move), and the step itself; or that it took the dispatcher
    /// route.
    static func breakdown() async throws -> [String] {
        guard try gpu() != nil else { return [] }
        var lines: [String] = []
        for slider in cases where !slider.live {
            // A route of its own: resident tiles keyed by another document's layer ids would compare pixels.
            guard let (_, route, target) = try gpu() else { return [] }
            var workspace = try PhotoRenderBudgetTests.document()
            let layer = try slider.setUp(&workspace)
            slider.step(&workspace, layer, 0)
            var shown = try await PhotoRenderer.update(workspace, since: nil, route: route, target: target).revision
            slider.step(&workspace, layer, 1)
            let clock = ContinuousClock()
            let t0 = clock.now
            let plan = workspace.liveStack()
            let planned = milliseconds(clock.now - t0)
            let made = route.composites.made
            let t1 = clock.now
            shown = try await PhotoRenderer.update(workspace, since: shown, route: route, target: target).revision
            let stepped = milliseconds(clock.now - t1)
            let line = plan == nil
                ? "ADJUST-BREAKDOWN-8K GPU-resident \(config) \(slider.name): dispatcher route (no live plan), step \(format(stepped)) ms"
                : "ADJUST-BREAKDOWN-8K GPU-resident \(config) \(slider.name): plan \(format(planned)) ms, \(route.composites.made - made) composites made again, step \(format(stepped)) ms"
            print(line)
            lines.append(line)
        }
        return lines
    }
}
