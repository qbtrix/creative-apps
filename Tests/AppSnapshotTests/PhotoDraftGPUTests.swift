// PhotoDraftGPUTests.swift: a Free Transform drag frame on a layer that can't lift (a non-normal blend on the
// layer, a blended layer above it, or a blended layer's selected part) draws on the GPU with Metal's `.affine` composite: on the resident route,
// with the app's texture target and without one, a rotate, a stretch and a shrink frame resample the layer on
// the CPU 0 times (PhotoRenderCount's `resamples` through a Tally, debug only; a shrink makes its halved source
// once per draft), and the frame's bytes match the CPU route's drag frame within a few levels (both bilinear).
// `blendedDragOn24Megapixels` times the rotate frame at 6000 x 4000 on the texture target in an optimized build
// (`swift test -c release -Xswiftc -DDEBUG -Xswiftc -enable-testing`): it fails over `budget`, a little above what
// it measures (p95 53 to 101 ms at load 30 to 36; the CPU resample measured 753 ms), and reports the 8 ms target.
// The rest is the live route's whole-canvas cost: each region copies its base onto a new Metal surface, which core
// fills from the CPU (qbtrix/creative-core#833). It reads the wall clock, so it stays disabled until
// Tests/perf-suites.txt lists it (#6380). macOS only, skipped without a GPU.
import CoreRaster
import CoreRender
import CoreRenderMetal
import Metal
@testable import PhotoModel
import SuiteKernel
import Testing

@testable import PhotoApp

@Suite struct PhotoDraftGPUTests {
    static let device = MetalBackend.defaultDevice

    enum Blend: String, CaseIterable, CustomStringConvertible, Sendable {
        /// Multiply on the dragged layer itself.
        case onTheLayer
        /// A normal dragged layer under a Screen layer.
        case above
        /// Multiply, the square selected on a layer painted outside it too: the rest draws as it is.
        case onPart
        var description: String { rawValue }
    }

    /// A white image, its left half cyan, with a red square on a second layer, Free Transform begun on it, and `blend` in place.
    static func draft(_ blend: Blend, width: Int, height: Int) throws -> PhotoWorkspace {
        var model = PhotoWorkspace()
        try model.newImage(DocumentSetup(width: Double(width), height: Double(height)))
        // A cyan left half under the square, so a blend that was dropped shows (multiply over white is the square).
        model.setToolOption(.color(red: 60, green: 180, blue: 220))
        model.setSelection(PixelRect(x: 0, y: 0, width: width / 2, height: height))
        model.fillSelection()
        model.deselect()
        model.addLayer()
        let dragged = try #require(model.selectedLayer?.id)
        model.setToolOption(.color(red: 200, green: 30, blue: 40))
        model.setSelection(PixelRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        model.fillSelection()
        model.deselect()
        switch blend {
        case .onTheLayer:
            model.setBlendMode(dragged, .multiply)
        case .onPart:
            model.setToolOption(.color(red: 30, green: 160, blue: 60))
            model.setSelection(PixelRect(x: width / 16, y: height / 16, width: width / 8, height: height / 8))
            model.fillSelection()
            model.setSelection(PixelRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
            model.setBlendMode(dragged, .multiply)
        case .above:
            model.addLayer()
            let top = try #require(model.selectedLayer?.id)
            model.setToolOption(.color(red: 20, green: 90, blue: 200))
            model.setSelection(PixelRect(x: 0, y: 0, width: width / 2, height: height))
            model.fillSelection()
            model.deselect()
            model.setBlendMode(top, .screen)
            model.selectLayer(dragged)
        }
        model.selectTool(.select)
        try model.beginTransform()
        #expect(model.transformDraft?.layerID == dragged, "\(blend): the draft isn't on the square's layer")
        return model
    }

    /// The drag's frames: a turn, a stretch past the layer's size, a shrink to under half.
    static let steps: [(String, @Sendable (TransformBox) -> TransformBox)] = [
        ("turn", { TransformRules.rotated($0, by: 7) }),
        ("stretch", { TransformRules.scaled($0, sx: 1.3, sy: 1.1, about: .center) }),
        ("shrink", { TransformRules.scaled($0, sx: 0.4, sy: 0.45, about: .center) }),
    ]

    @Test(.enabled(if: device != nil), arguments: Blend.allCases)
    func aBlendedDragFrameDrawsOnTheGPU(_ blend: Blend) async throws {
        let metal = try MetalBackend(device: #require(Self.device), cacheURL: nil)
        #expect(metal.supports.contains(.affine))
        var workspace = try Self.draft(blend, width: 600, height: 400)
        let base = try #require(workspace.transformSelection)
        let gpu = PhotoRenderRoute(preferred: metal, resident: ResidentSurfaces(backend: metal))
        let textured = PhotoRenderRoute(preferred: metal, resident: ResidentSurfaces(backend: metal))
        let target = try PhotoRenderBudgetTests.textureTarget(metal, width: 600, height: 400)
        var shown = try await PhotoRenderer.update(workspace, since: nil, route: gpu).revision
        var shownTextured = try await PhotoRenderer.update(workspace, since: nil, route: textured, target: target).revision
        for (name, step) in Self.steps {
            try workspace.setTransform(step(base), name: "Transform", drag: name)
            let tally = PhotoRenderCount.Tally()
            let frame = try await PhotoRenderCount.$tally.withValue(tally) {
                try await PhotoRenderer.update(workspace, since: shown, route: gpu, live: true)
            }
            let texturedTally = PhotoRenderCount.Tally()
            shownTextured = try await PhotoRenderCount.$tally.withValue(texturedTally) {
                try await PhotoRenderer.update(workspace, since: shownTextured, route: textured, target: target, live: true)
            }.revision
            shown = frame.revision
            #if DEBUG
            // A shrink's halved source is made once per draft (at most two halvings here), never per frame.
            let allowed = name == "shrink" ? 2 : 0
            #expect(tally.snapshot["resamples", default: 0] <= allowed, "\(blend) \(name): resampled on the CPU \(tally.snapshot)")
            #expect(texturedTally.snapshot["resamples", default: 0] <= allowed,
                    "\(blend) \(name): the texture route resampled on the CPU \(texturedTally.snapshot)")
            #endif
            let reference = try await PhotoRenderer.update(workspace, since: nil, route: .cpu, live: true)
            let (got, want) = (PhotoRenderBackendTests.laid(try await PhotoRenderer.update(workspace, since: nil, route: gpu, live: true)),
                               PhotoRenderBackendTests.laid(reference))
            #expect(got.count == want.count)
            let off = stride(from: 0, to: min(got.count, want.count), by: 4).filter { i in
                (i..<(i + 4)).contains { abs(Int(got[$0]) - Int(want[$0])) > 6 }
            }.count
            if name == "shrink" {
                // The GPU shrinks from a halved source, the CPU samples the layer sparsely: they part only in
                // a band about 4 px wide along the square's shrunk edges (about 420 px around), never inside or off it.
                #expect(off <= 1700, "\(blend) shrink: \(off) pixels are more than 6 levels off the CPU frame")
            } else {
                // Both bilinear at a stretch of 1 or more; the GPU samples in half floats.
                #expect(off == 0, "\(blend) \(name): \(off) pixels are more than 6 levels off the CPU frame")
            }
        }
        // The next shrink frame of the drag draws from the halved source already made.
        shown = try await PhotoRenderer.update(workspace, since: shown, route: gpu, live: true).revision
        try workspace.setTransform(TransformRules.scaled(base, sx: 0.42, sy: 0.44, about: .center), name: "Transform", drag: "shrink")
        let again = PhotoRenderCount.Tally()
        _ = try await PhotoRenderCount.$tally.withValue(again) {
            try await PhotoRenderer.update(workspace, since: shown, route: gpu, live: true)
        }
        #if DEBUG
        #expect(again.snapshot["resamples", default: 0] == 0, "\(blend): the next shrink frame halved the layer again \(again.snapshot)")
        #endif
    }

    /// The 24 MP frame's p95 budget in an optimized build; the target is 8 ms once core#833 lands.
    static let budget = 150.0

    /// One display frame's half: a 24 MP blended layer's rotate frame on the app's texture target.
    @Test(.disabled("reads the wall clock: waits on a Tests/perf-suites.txt line (#6380)"),
          .enabled(if: device != nil), .timeLimit(.minutes(5)))
    func blendedDragOn24Megapixels() async throws {
        let metal = try MetalBackend(device: #require(Self.device), cacheURL: nil)
        var workspace = try Self.draft(.onTheLayer, width: 6000, height: 4000)
        let route = PhotoRenderRoute(preferred: metal, resident: ResidentSurfaces(backend: metal))
        let target = try PhotoRenderBudgetTests.textureTarget(metal, width: 6000, height: 4000)
        var shown = try await PhotoRenderer.update(workspace, since: nil, route: route, target: target).revision
        let clock = ContinuousClock()
        var times: [Double] = []
        let tally = PhotoRenderCount.Tally()
        // An unoptimized build proves the route in a few frames; an optimized one (`-c release`) times 70.
        let optimized = !_isDebugAssertConfiguration()
        let frames = optimized ? 70 : 4
        for i in 0..<frames {
            guard let box = workspace.transformSelection else { break }
            try workspace.setTransform(TransformRules.rotated(box, by: 1), name: "Rotate", drag: "turn")
            let started = clock.now
            shown = try await PhotoRenderCount.$tally.withValue(tally) {
                try await PhotoRenderer.update(workspace, since: shown, route: route, target: target, live: true)
            }.revision
            if i >= frames / 7 { times.append(milliseconds(clock.now - started)) }  // the first frames warm the pipelines
        }
        times.sort()
        let p95 = times[min(times.count - 1, times.count * 95 / 100)]
        print("PhotoDraftGPUTests 24 MP blended turn frame: p50 \(times[times.count / 2]) ms, p95 \(p95) ms, tally \(tally.snapshot)")
        #if DEBUG
        #expect(tally.snapshot["resamples", default: 0] == 0, "the drag resampled on the CPU: \(tally.snapshot)")
        #endif
        if optimized { #expect(p95 <= Self.budget, "24 MP blended turn frame p95 \(p95) ms, over \(Self.budget) ms (target 8 ms)") }
    }
}
