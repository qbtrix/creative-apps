// BucketRulesTests.swift (fill-heal FH-1 written, FH-5b on): the paint
// bucket's region and fill over creative-core's flood mask. Tolerance 0 fills
// one colour's region exactly, contiguous off fills every match, nothing
// outside the selection changes, and All Layers samples the merged picture
// but writes only the target. Mutations (FH-5b): SuiteImaging.BucketRules
// (`.insideSelectionOnly`, `.contiguousStopsAtEdges`); #5093 (the anti-aliased
// edge stays inside the tolerance): `.edgeStaysInside`, `.edgeBlendsByOwnCoverage`.
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

    /// sRGB (20, 40, 110) as the buffer's linear components, as a PNG decodes.
    static let navy = RGBA(r: 0.006995, g: 0.021219, b: 0.155926, a: 1)
    /// 16 x 16 navy with a white square at 4..<12 and, when `ring` is set, a 1-px ring of `ring` around it.
    static func framedSquare(ring: RGBA?) throws -> PixelBuffer {
        var p = try PixelBuffer(width: 16, height: 16, fill: navy)
        for y in 3..<13 { for x in 3..<13 { try p.setPixel(x: x, y: y, (4..<12).contains(x) && (4..<12).contains(y) ? white : ring ?? navy) } }
        return p
    }

    /// Fills `p` from (8, 8) and checks every pixel outside the square is byte-identical and the square's
    /// inside (past its 1-px edge) is red; returns the filled pixels.
    static func expectOnlyTheSquareChanges(_ p: PixelBuffer, tolerance: Int) throws -> PixelBuffer {
        let region = try BucketRules.region(seed: (8, 8), in: p, options: BucketOptions(tolerance: tolerance), selection: nil)
        let filled = try BucketRules.fill(p, region: region, color: red)
        for y in 0..<16 {
            for x in 0..<16 {
                if (5..<11).contains(x) && (5..<11).contains(y) { #expect(try filled.pixel(x: x, y: y) == red, "(\(x), \(y))") }
                if !((4..<12).contains(x) && (4..<12).contains(y)) { #expect(try filled.pixel(x: x, y: y) == p.pixel(x: x, y: y), "(\(x), \(y))") }
            }
        }
        return filled
    }

    @Test func aTwoColourSquareChangesOnlyItsInsideAndRing() throws {
        _ = try Self.expectOnlyTheSquareChanges(Self.framedSquare(ring: nil), tolerance: 0)
        _ = try Self.expectOnlyTheSquareChanges(Self.framedSquare(ring: nil), tolerance: 32)
    }

    @Test func anEdgePixelPastTheToleranceStaysUnchanged() throws {
        // RJ-P51's outermost logo edge: about 69 % white, past tolerance 32 but within twice it.
        let mixed = RGBA(r: 0.467784, g: 0.502886, b: 0.644480, a: 1) // sRGB (182, 188, 210)
        let filled = try Self.expectOnlyTheSquareChanges(Self.framedSquare(ring: mixed), tolerance: 32)
        #expect(try filled.pixel(x: 4, y: 8) == Self.red, "a white edge pixel is all fill")
    }

    @Test func aHolePastTheToleranceStaysUnchanged() throws {
        var p = try Self.framedSquare(ring: nil)
        let mixed = RGBA(r: 0.467784, g: 0.502886, b: 0.644480, a: 1), options = BucketOptions(tolerance: 32)
        try p.setPixel(x: 8, y: 6, mixed)
        let filled = try BucketRules.fill(p, region: BucketRules.region(seed: (8, 8), in: p, options: options, selection: nil), color: Self.red)
        #expect(try filled.pixel(x: 8, y: 6) == mixed && filled.pixel(x: 8, y: 5) == Self.red)
    }

    @Test func anEdgePixelWithinTheToleranceBlendsByItsOwnCoverage() throws {
        var p = try Self.framedSquare(ring: nil)
        let nearWhite = RGBA(r: 0.830770, g: 0.854993, b: 0.913099, a: 1) // sRGB (235, 238, 245)
        try p.setPixel(x: 4, y: 8, nearWhite)
        try p.setPixel(x: 7, y: 8, nearWhite)
        let filled = try Self.expectOnlyTheSquareChanges(p, tolerance: 32)
        let edge = try filled.pixel(x: 4, y: 8)
        #expect(edge.r > 0.9 && edge.g > 0.01 && edge.g < nearWhite.g, "edge \(edge): part fill, part its own colour")
        #expect(try filled.pixel(x: 7, y: 8) == Self.red, "inside the edge a taken pixel is all fill")
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
