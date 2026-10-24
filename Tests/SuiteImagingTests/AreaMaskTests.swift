// AreaMaskTests.swift (area-selection AR-5 written, AR-6 on): the kernel's area recipe as a CoreRaster mask on
// 64 x 64 fixtures. Ellipse minus lasso matches core's own shapes within 1/255; the wand at tolerance 10 stops at
// a 20-level edge and with Contiguous off takes both islands; a feather before a subtract keeps the cut hard;
// expand 2 grows a square by 2 each side and contract 2 restores it. Mutations: SuiteImaging.AreaMask.
import CoreRaster
import Testing
import SuiteKernel
import SuiteImaging

@Suite struct AreaMaskTests {
    static let size = 64
    static func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Rect {
        Rect(minX: x, minY: y, maxX: x + w, maxY: y + h)
    }
    static func recipe(_ steps: [AreaRecipe.Step]) -> AreaRecipe {
        var recipe = AreaRecipe()
        for step in steps { recipe.apply(step) }
        return recipe
    }
    static func mask(_ steps: [AreaRecipe.Step], sources: AreaMask.Sources? = nil) throws -> Mask {
        try AreaMask.mask(recipe(steps), width: size, height: size, sources: sources)
    }
    /// A buffer filled by `color(x, y)`.
    static func picture(_ color: (Int, Int) -> RGBA) throws -> PixelBuffer {
        var p = try PixelBuffer(width: size, height: size)
        for y in 0..<size { for x in 0..<size { try p.setPixel(x: x, y: y, color(x, y)) } }
        return p
    }
    static func grey(_ v: Float) -> RGBA { RGBA(r: v, g: v, b: v, a: 1) }

    @Test func ellipseMinusLassoMatchesCoreShapes() throws {
        let notch: [Point] = [Point(x: 32, y: 0), Point(x: 64, y: 0), Point(x: 64, y: 64), Point(x: 32, y: 64)]
        let area = try Self.mask([.shape(.ellipse(Self.rect(8, 8, 48, 48)), .replace), .shape(.lasso(notch), .subtract)])
        var expected = try Mask.ellipse(width: 64, height: 64, centerX: 32, centerY: 32, radiusX: 24, radiusY: 24)
        try expected.subtract(Mask.polygon(width: 64, height: 64, points: notch.map { Mask.Point(x: $0.x, y: $0.y) }))
        for y in 0..<64 {
            for x in 0..<64 {
                #expect(abs(try area.coverage(x: x, y: y) - expected.coverage(x: x, y: y)) <= 1 / 255, "(\(x), \(y))")
            }
        }
        #expect(try area.coverage(x: 16, y: 32) == 1)
        #expect(try area.coverage(x: 40, y: 32) == 0)
    }

    @Test func addThenIntersectKeepsTheShared() throws {
        let area = try Self.mask([
            .shape(.rect(Self.rect(0, 0, 16, 16)), .replace), .shape(.rect(Self.rect(32, 0, 16, 16)), .add),
            .shape(.rect(Self.rect(8, 0, 32, 16)), .intersect),
        ])
        #expect(try area.coverage(x: 4, y: 4) == 0)
        #expect(try area.coverage(x: 12, y: 4) == 1)
        #expect(try area.coverage(x: 24, y: 4) == 0)
        #expect(try area.coverage(x: 36, y: 4) == 1)
        #expect(try area.coverage(x: 44, y: 4) == 0)
        #expect(abs(area.area - 256) < 0.5)
    }

    @Test func invertSelectsTheRest() throws {
        let area = try Self.mask([.shape(.rect(Self.rect(16, 16, 32, 32)), .replace), .invert])
        #expect(try area.coverage(x: 20, y: 20) == 0)
        #expect(try area.coverage(x: 4, y: 4) == 1)
        #expect(abs(area.area - Double(64 * 64 - 32 * 32)) < 0.5)
    }

    @Test func wandStopsAtATwentyLevelEdge() throws {
        let p = try Self.picture { x, _ in Self.grey(x < 32 ? 0.2 : 0.2 + 20 / 255) }
        let sources = AreaMask.Sources(layer: p, composite: p)
        let tight = try Self.mask([.shape(.wand(seed: Point(x: 8.5, y: 8.5), tolerance: 10, contiguous: true, allLayers: false), .replace)],
                                  sources: sources)
        for y in [0, 31, 63] {
            #expect(try tight.coverage(x: 31, y: y) == 1)
            for x in 34..<64 { #expect(try tight.coverage(x: x, y: y) == 0, "(\(x), \(y))") }
        }
        let loose = try Self.mask([.shape(.wand(seed: Point(x: 8.5, y: 8.5), tolerance: 30, contiguous: true, allLayers: false), .replace)],
                                  sources: sources)
        #expect(abs(loose.area - 64 * 64) < 0.5)
    }

    @Test func contiguousOffPicksBothIslands() throws {
        let red = RGBA(r: 1, g: 0, b: 0, a: 1)
        let p = try Self.picture { x, y in (4..<12).contains(y) && ((4..<12).contains(x) || (40..<48).contains(x)) ? red : Self.grey(1) }
        let sources = AreaMask.Sources(layer: p, composite: p)
        let seed = Point(x: 6, y: 6)
        let one = try Self.mask([.shape(.wand(seed: seed, tolerance: 10, contiguous: true, allLayers: false), .replace)], sources: sources)
        let both = try Self.mask([.shape(.wand(seed: seed, tolerance: 10, contiguous: false, allLayers: false), .replace)], sources: sources)
        #expect(try one.coverage(x: 8, y: 8) == 1)
        #expect(try one.coverage(x: 44, y: 8) == 0)
        #expect(try both.coverage(x: 8, y: 8) == 1)
        #expect(try both.coverage(x: 44, y: 8) == 1)
        #expect(try both.coverage(x: 24, y: 8) == 0)
    }

    @Test func allLayersSamplesTheComposite() throws {
        let flat = try PixelBuffer(width: 64, height: 64, fill: Self.grey(1))
        let composite = try Self.picture { x, y in x < 16 && y < 16 ? Self.grey(0) : Self.grey(1) }
        let sources = AreaMask.Sources(layer: flat, composite: composite)
        let wand = { (all: Bool) in AreaShape.wand(seed: Point(x: 4, y: 4), tolerance: 10, contiguous: true, allLayers: all) }
        #expect(abs(try Self.mask([.shape(wand(false), .replace)], sources: sources).area - 64 * 64) < 0.5)
        #expect(try Self.mask([.shape(wand(true), .replace)], sources: sources).coverage(x: 32, y: 32) == 0)
    }

    @Test func wandWithoutSourcesThrows() {
        #expect(throws: (any Error).self) {
            try Self.mask([.shape(.wand(seed: Point(x: 4, y: 4), tolerance: 10, contiguous: true, allLayers: false), .replace)])
        }
    }

    @Test func featherMakesARampAtLeastSixPixelsWide() throws {
        let area = try Self.mask([.shape(.rect(Self.rect(16, 16, 32, 32)), .replace), .feather(4)])
        let ramp = try (0..<32).filter { x in
            let c = try area.coverage(x: x, y: 32)
            return c > 1 / 255 && c < 254 / 255
        }
        #expect(ramp.count >= 6)
        #expect(abs(try area.coverage(x: 16, y: 32) - 0.5) < 0.2)
    }

    @Test func featherThenSubtractKeepsTheCutHard() throws {
        let area = try Self.mask([
            .shape(.rect(Self.rect(8, 8, 48, 48)), .replace), .feather(4), .shape(.rect(Self.rect(32, 0, 32, 64)), .subtract),
        ])
        #expect(try area.coverage(x: 31, y: 32) > 0.99)
        #expect(try area.coverage(x: 32, y: 32) == 0)
    }

    @Test func expandGrowsByTheRadiusAndContractRestores() throws {
        let square = [AreaRecipe.Step.shape(.rect(Self.rect(20, 20, 24, 24)), .replace)]
        let original = try Self.mask(square)
        let grown = try Self.mask(square + [.expand(2)])
        #expect(try grown.coverage(x: 18, y: 32) == 1)
        #expect(try grown.coverage(x: 17, y: 32) == 0)
        #expect(try grown.coverage(x: 45, y: 32) == 1)
        #expect(try grown.coverage(x: 46, y: 32) == 0)
        #expect(try grown.coverage(x: 18, y: 18) == 0)
        let restored = try Self.mask(square + [.expand(2), .expand(-2)])
        #expect(restored == original)
        let shrunk = try Self.mask(square + [.expand(-2)])
        #expect(try shrunk.coverage(x: 22, y: 32) == 1)
        #expect(try shrunk.coverage(x: 21, y: 32) == 0)
    }

    @Test func outlineTracesEachRegion() throws {
        let area = try Self.mask([
            .shape(.rect(Self.rect(4, 4, 16, 16)), .replace), .shape(.ellipse(Self.rect(32, 32, 24, 24)), .add),
        ])
        let rings = try AreaMask.outline(area)
        #expect(rings.count == 2)
        for ring in rings { #expect(ring.count >= 3 && ring.allSatisfy { (0...64).contains($0.x) && (0...64).contains($0.y) }) }
        #expect(try AreaMask.outline(Mask(width: 64, height: 64)).isEmpty)
    }
}
