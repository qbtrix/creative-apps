// BucketRulesTests.swift (fill-heal FH-1 written, FH-5b on): the paint
// bucket's region and fill over creative-core's flood mask. Tolerance 0 fills
// one colour's region exactly, contiguous off fills every match, nothing
// outside the selection changes, and All Layers samples the merged picture
// but writes only the target. Mutations (FH-5b): SuiteImaging.BucketRules
// (`.insideSelectionOnly`, `.contiguousStopsAtEdges`).
import CoreRaster
import Testing
import SuiteImaging

@Suite struct BucketRulesTests {
    static let black = RGBA(r: 0, g: 0, b: 0, a: 1), white = RGBA(r: 1, g: 1, b: 1, a: 1), red = RGBA(r: 1, g: 0, b: 0, a: 1)
    /// The two white squares on black: A at x 2..<6, B at x 10..<14, both y 2..<6.
    static let squares: Set<[Int]> = Set((2..<6).flatMap { y in (Array(2..<6) + Array(10..<14)).map { [$0, y] } })

    /// 16 x 8 black with the two white squares.
    static func twoSquares() throws -> PixelBuffer {
        var p = try PixelBuffer(width: 16, height: 8, fill: black)
        for xy in squares { try p.setPixel(x: xy[0], y: xy[1], white) }
        return p
    }
    /// The pixels whose coverage is above 0.
    static func covered(_ m: Mask) throws -> Set<[Int]> {
        var out: Set<[Int]> = []
        for y in 0..<m.height { for x in 0..<m.width where try m.coverage(x: x, y: y) > 0 { out.insert([x, y]) } }
        return out
    }

    @Test func toleranceZeroFillsOneRegionExactly() throws {
        let p = try Self.twoSquares()
        let options = BucketOptions(tolerance: 0)
        let region = try BucketRules.region(seed: (3, 3), in: p, options: options, selection: nil)
        #expect(try Self.covered(region) == Self.squares.filter { $0[0] < 8 })
        let filled = try BucketRules.fill(p, region: region, color: Self.red)
        for y in 0..<8 {
            for x in 0..<16 {
                let want = x < 8 && Self.squares.contains([x, y]) ? Self.red : try p.pixel(x: x, y: y)
                #expect(try filled.pixel(x: x, y: y) == want, "(\(x), \(y))")
            }
        }
    }

    @Test func contiguousOffFillsEveryMatch() throws {
        let p = try Self.twoSquares()
        let region = try BucketRules.region(seed: (3, 3), in: p, options: BucketOptions(tolerance: 0, contiguous: false), selection: nil)
        #expect(try Self.covered(region) == Self.squares)
    }

    @Test func nothingOutsideTheSelectionChanges() throws {
        let p = try Self.twoSquares()
        let selection = try Mask.rectangle(width: 16, height: 8, x: 0, y: 0, w: 4, h: 8)
        let region = try BucketRules.region(seed: (3, 3), in: p, options: BucketOptions(tolerance: 0), selection: selection)
        #expect(try Self.covered(region) == Self.squares.filter { $0[0] < 4 })
        let filled = try BucketRules.fill(p, region: region, color: Self.red)
        #expect(try filled.pixel(x: 3, y: 3) == Self.red && filled.pixel(x: 4, y: 3) == Self.white && filled.pixel(x: 5, y: 5) == Self.white)
    }

    @Test func allLayersSamplesTheMergedPictureButWritesTheTarget() throws {
        let merged = try Self.twoSquares()
        let target = try PixelBuffer(width: 16, height: 8)
        let region = try BucketRules.region(seed: (11, 3), in: merged, options: BucketOptions(tolerance: 32, sampleAllLayers: true), selection: nil)
        let filled = try BucketRules.fill(target, region: region, color: Self.red)
        #expect(try filled.pixel(x: 11, y: 3) == Self.red && filled.pixel(x: 3, y: 3) == .clear && filled.pixel(x: 0, y: 0) == .clear)
        #expect(try BucketRules.fill(target, region: Mask(width: 16, height: 8), color: Self.red) == target)
    }

    @Test func optionsDefaultToContiguousAntiAliasedOnOneLayer() throws {
        let o = BucketOptions(tolerance: 32)
        #expect(o.contiguous && o.antiAlias && !o.sampleAllLayers)
        #expect(BucketOptions(tolerance: 900).tolerance == 255 && BucketOptions(tolerance: -4).tolerance == 0)
        #expect(throws: (any Error).self) {
            try BucketRules.region(seed: (99, 0), in: try Self.twoSquares(), options: o, selection: nil)
        }
    }
}
