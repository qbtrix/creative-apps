// LiveLayerRouteTests.swift: the live layer route (suite-imaging IM-8d, slice
// IM-photo, lifted from Photo's PhotoLiveTone). The fold: the pixel layers under
// the lowest adjustment layer are the base, the top normal adjustment layers at
// full opacity run before the image's own operations in the display program,
// and the rest stay steps; an opacity outside 0...1 or a layer the route can't
// draw sends the stack to the dispatcher route. The draw: a region is the
// cached base, the steps on tone passes (a faded or blended adjustment layer
// composited back), then one write with the display program; a second draw of
// the same layers composites nothing. CoreRender's CPU backend stands in for
// the GPU, so it all runs on Linux.
import CoreRaster
import CoreRender
import Testing
import SuiteImaging

/// A layer as an app hands it to the live route: a name, and the pixels it draws.
private struct Layer: LiveLayer {
    var name: String
    var liveKind: LiveLayerKind = .pixels
    var blendMode: BlendMode = .normal
    var opacity: Double = 1
    var color = RGBA(r: 0, g: 0, b: 0, a: 0)
    var liveKey: String { "\(name) \(blendMode) \(opacity) \(color)" }
}

private typealias Stack = LiveLayerStack<Layer>

/// A region of the picture.
private struct Rect: LiveRegion {
    var x = 0, y = 0, width: Int, height: Int
}

private enum Fixture {
    static let (width, height) = (8, 4)
    static let rect = Rect(width: width, height: height)
    static let bright: [ToneProgram.Operation] = [.adjustment(.exposure(stops: 0.5))]
    static let dark: [ToneProgram.Operation] = [.adjustment(.exposure(stops: -1))]
    static let image: [ToneProgram.Operation] = [.matrix(rows: [0, 1, 0, 1, 0, 0, 0, 0, 1], lightness: 0)]

    static let red = Layer(name: "red", color: RGBA(r: 0.8, g: 0.1, b: 0.2, a: 1))
    static let blue = Layer(name: "blue", blendMode: .screen, opacity: 0.6, color: RGBA(r: 0.1, g: 0.3, b: 0.9, a: 1))

    static func adjustment(_ name: String, _ ops: [ToneProgram.Operation], mode: BlendMode = .normal, opacity: Double = 1) -> Layer {
        Layer(name: name, liveKind: .adjustment(ops), blendMode: mode, opacity: opacity)
    }

    /// A solid layer's one composite step over the region, its tile resident.
    static func tiles(_ layers: [Layer], _ rect: Rect, _ resident: ResidentSurfaces) throws -> [CompositeStep] {
        try layers.compactMap { layer in
            var pixels = try PixelBuffer(width: rect.width, height: rect.height)
            for y in 0..<rect.height { for x in 0..<rect.width { try pixels.setPixel(x: x, y: y, layer.color) } }
            return try resident.surface(ResidentKey(layer: layer.liveKey, tile: 0), pixels: pixels).map {
                CompositeStep($0, x: 0, y: 0, mode: layer.blendMode, opacity: Float(layer.opacity))
            }
        }
    }

    /// `stack` drawn on a stand-in GPU: the written picture's first pixel.
    static func draw(_ stack: Stack, cache: LiveCompositeCache<Rect> = LiveCompositeCache(),
                     gpu: CPUBackend = CPUBackend(name: "stand-in")) throws -> RGBA {
        let resident = ResidentSurfaces(backend: gpu)
        let dispatcher = RenderDispatcher(preferred: gpu, fallback: CPUBackend())
        var written: RGBA?
        try stack.draw(rect, on: dispatcher, resident: resident, tone: gpu, cache: cache, tiles: tiles) { surface, _, tone in
            let toned = try gpu.adjusted(surface, tone: tone)
            defer { gpu.release(toned) }
            written = try gpu.read(toned).pixel(x: 0, y: 0)
        }
        return try #require(written)
    }

    /// `layers` composited bottom up on the CPU, each adjustment layer run over everything under it.
    static func reference(_ layers: [Layer], image: [ToneProgram.Operation]) throws -> RGBA {
        let cpu = CPUBackend()
        var picture = try cpu.surface(PixelBuffer(width: width, height: height))
        for layer in layers {
            var steps = try tiles([layer], rect, ResidentSurfaces(backend: cpu))
            if case .adjustment(let ops) = layer.liveKind {
                steps = [CompositeStep(try cpu.adjusted(picture, tone: ToneProgram(operations: ops)), x: 0, y: 0,
                                       mode: layer.blendMode, opacity: Float(layer.opacity))]
            }
            try cpu.composite(steps, onto: &picture)
        }
        return try cpu.read(cpu.adjusted(picture, tone: ToneProgram(operations: image))).pixel(x: 0, y: 0)
    }

    static func near(_ a: RGBA, _ b: RGBA) -> Bool {
        max(abs(a.r - b.r), abs(a.g - b.g), abs(a.b - b.b), abs(a.a - b.a)) < 1.0 / 255
    }
}

@Suite struct LiveLayerRouteTests {
    @Test func theTopAdjustmentLayersRunBeforeTheImages() throws {
        let stack = try #require(Stack.folding(
            [Fixture.red, Fixture.adjustment("a", Fixture.bright), Fixture.adjustment("b", Fixture.dark)], image: Fixture.image))
        #expect(stack.base.map(\.name) == ["red"])
        #expect(stack.steps.isEmpty)
        #expect(stack.display == (try ToneProgram(operations: Fixture.bright + Fixture.dark + Fixture.image)))
    }

    @Test func anAdjustmentLayerUnderPixelsOrFadedStaysAStep() throws {
        let under = try #require(Stack.folding(
            [Fixture.red, Fixture.adjustment("a", Fixture.bright), Fixture.blue], image: Fixture.image))
        #expect(under.base.map(\.name) == ["red"])
        #expect(under.steps.count == 2)
        #expect(under.display == (try ToneProgram(operations: Fixture.image)))
        let faded = try #require(Stack.folding(
            [Fixture.red, Fixture.adjustment("a", Fixture.bright, mode: .multiply, opacity: 0.5)], image: []))
        #expect(faded.steps.count == 1)
        #expect(faded.display.isEmpty)
    }

    @Test func aLayerTheRouteCantDrawSendsItToTheDispatcher() {
        var odd = Fixture.blue
        odd.opacity = 1.5
        #expect(Stack.folding([Fixture.red, odd], image: []) == nil)
        #expect(Stack.folding([Fixture.red, Layer(name: "masked", liveKind: .unsupported)], image: []) == nil)
        #expect(Stack.folding([Fixture.red, Fixture.adjustment("bad", [.matrix(rows: [1], lightness: 0)])], image: []) == nil)
    }

    @Test(arguments: [0, 1, 2])
    func aRegionIsTheReference(at position: Int) throws {
        // 0: the adjustment layer on top; 1: under the screened layer; 2: on top at 50 % Multiply.
        let layer = Fixture.adjustment("a", Fixture.dark, mode: position == 2 ? .multiply : .normal, opacity: position == 2 ? 0.5 : 1)
        let layers = position == 1 ? [Fixture.red, layer, Fixture.blue] : [Fixture.red, Fixture.blue, layer]
        let stack = try #require(Stack.folding(layers, image: Fixture.image))
        let drawn = try Fixture.draw(stack)
        let reference = try Fixture.reference(layers, image: Fixture.image)
        #expect(Fixture.near(drawn, reference), "position \(position): \(drawn) against \(reference)")
    }

    @Test func aSecondDrawCompositesNothingAndNewLayersReplaceTheBase() throws {
        let (cache, gpu) = (LiveCompositeCache<Rect>(), CPUBackend(name: "stand-in"))
        let stack = try #require(Stack.folding([Fixture.red, Fixture.adjustment("a", Fixture.dark)], image: []))
        _ = try Fixture.draw(stack, cache: cache, gpu: gpu)
        _ = try Fixture.draw(stack, cache: cache, gpu: gpu)
        #expect(cache.made == 1, "a slider step composited the layers again")
        var moved = Fixture.red
        moved.opacity = 0.5
        let other = try #require(Stack.folding([moved, Fixture.adjustment("a", Fixture.dark)], image: []))
        _ = try Fixture.draw(other, cache: cache, gpu: gpu)
        #expect(cache.made == 2)
        #expect(cache.count == 1)
        cache.removeAll()
        #expect(cache.count == 0)
    }
}
