// HealRulesTests.swift (fill-heal FH-1 written, FH-5h on): spot heal, heal and
// remove over creative-core's heal and fill. A dot on flat sky heals to within
// 3 levels of the sky, heal copies texture from its source offset, remove of
// a square on a texture leaves no pixel of the square's colour, and the same
// seed gives the same pixels. Mutations (FH-5h): SuiteImaging.HealRules
// (`.removeIsRepeatable`, `.healCopiesFromSource`,
// `.healSkipsOffCanvasSource`, `.healClipsBothAxes`).
import CoreRaster
import Testing
import SuiteKernel
import SuiteImaging

@Suite struct HealRulesTests {
    static let sky = RGBA(r: 0.4, g: 0.6, b: 0.9, a: 1)
    static let red = RGBA(r: 1, g: 0, b: 0, a: 1)

    /// A 64 x 64 blue-green texture (a fixed hash per pixel) with a red 8 x 8 square at (28, 28).
    static func texture() throws -> PixelBuffer {
        var p = try PixelBuffer(width: 64, height: 64)
        for y in 0..<64 {
            for x in 0..<64 {
                let h = Float((x &* 73 &+ y &* 151 &+ (x * y) % 7) % 32) / 32
                let inSquare = (28..<36).contains(x) && (28..<36).contains(y)
                try p.setPixel(x: x, y: y, inSquare ? red : RGBA(r: 0.1, g: 0.3 + 0.4 * h, b: 0.7 - 0.3 * h, a: 1))
            }
        }
        return p
    }
    static let square = (try? Mask.rectangle(width: 64, height: 64, x: 28, y: 28, w: 8, h: 8))

    @Test func spotHealOnFlatSkyLeavesSky() throws {
        var p = try PixelBuffer(width: 48, height: 48, fill: Self.sky)
        for y in 22..<27 { for x in 22..<27 { try p.setPixel(x: x, y: y, RGBA(r: 0.05, g: 0.05, b: 0.05, a: 1)) } }
        let healed = try HealRules.spotHeal(p, at: (24, 24), size: 12, seed: 1)
        for y in 0..<48 {
            for x in 0..<48 {
                let c = try healed.pixel(x: x, y: y)
                #expect(abs(c.r - Self.sky.r) <= 3 / 255 && abs(c.g - Self.sky.g) <= 3 / 255 && abs(c.b - Self.sky.b) <= 3 / 255, "(\(x), \(y))")
            }
        }
    }

    @Test func healCopiesTextureFromTheSource() throws {
        // Left half: grey stripes one column wide; right half flat grey. The square at x 40..<50 takes the stripes 24 px left.
        var p = try PixelBuffer(width: 64, height: 32)
        for y in 0..<32 {
            for x in 0..<64 {
                let v: Float = x >= 32 ? 0.5 : x % 2 == 0 ? 0.2 : 0.8
                try p.setPixel(x: x, y: y, RGBA(r: v, g: v, b: v, a: 1))
            }
        }
        let mask = try Mask.rectangle(width: 64, height: 32, x: 40, y: 10, w: 10, h: 10)
        let healed = try HealRules.heal(p, through: mask, sourceOffset: (dx: -24, dy: 0))
        for x in 41..<49 { #expect(abs(try healed.pixel(x: x + 1, y: 15).r - healed.pixel(x: x, y: 15).r) > 0.3, "x \(x)") }
        #expect(try healed.pixel(x: 55, y: 15) == p.pixel(x: 55, y: 15) && healed.pixel(x: 10, y: 15) == p.pixel(x: 10, y: 15))
    }

    @Test func healSkipsDabsWhoseSourceIsOffTheCanvas() throws {
        // Flat grey with stripes from x 48. A band from x 10 to the right edge, source +40: x 10..<24 heal from
        // the stripes, x 24 on read past the edge and stay as they were (#5095).
        var p = try PixelBuffer(width: 64, height: 32)
        for y in 0..<32 {
            for x in 0..<64 {
                let v: Float = x < 48 ? 0.5 : x % 2 == 0 ? 0.2 : 0.8
                try p.setPixel(x: x, y: y, RGBA(r: v, g: v, b: v, a: 1))
            }
        }
        let band = try Mask.rectangle(width: 64, height: 32, x: 10, y: 10, w: 54, h: 10)
        let healed = try HealRules.heal(p, through: band, sourceOffset: (dx: 40, dy: 0))
        for x in 11..<22 { #expect(abs(try healed.pixel(x: x + 1, y: 15).r - healed.pixel(x: x, y: 15).r) > 0.3, "x \(x)") }
        for y in 0..<32 { for x in 24..<64 { #expect(try healed.pixel(x: x, y: y) == p.pixel(x: x, y: y), "(\(x), \(y))") } }
        #expect(try HealRules.heal(p, through: band, sourceOffset: (dx: 0, dy: 30)) == p)
        #expect(try HealRules.heal(p, through: band, sourceOffset: (dx: Int.min, dy: Int.max)) == p)
    }

    @Test func removeLeavesNoPixelOfTheSquaresColour() throws {
        let p = try Self.texture(), square = try #require(Self.square)
        let removed = try HealRules.remove(p, through: square, seed: 7)
        for y in 0..<64 {
            for x in 0..<64 {
                let c = try removed.pixel(x: x, y: y)
                #expect(!(c.r > 0.5 && c.g < 0.3), "(\(x), \(y)) still red")
            }
        }
    }

    @Test func theSameSeedGivesTheSamePixels() throws {
        let p = try Self.texture(), square = try #require(Self.square)
        #expect(try HealRules.remove(p, through: square, seed: 7) == HealRules.remove(p, through: square, seed: 7))
        #expect(try HealRules.spotHeal(p, at: (31, 31), size: 10, seed: 3) == HealRules.spotHeal(p, at: (31, 31), size: 10, seed: 3))
    }

    @Test func maskPlacesTheGridInTheBuffer() throws {
        let grid = CoverageGrid(originX: -1, originY: 3, width: 3, height: 1, values: [1, 0.5, 1])
        let m = try HealRules.mask(grid, width: 8, height: 6)
        #expect(m.width == 8 && m.height == 6)
        #expect(try m.coverage(x: 0, y: 3) == 0.5 && m.coverage(x: 1, y: 3) == 1 && m.coverage(x: 2, y: 3) == 0)
        #expect(try m.coverage(x: 0, y: 2) == 0 && m.area == 1.5)
        #expect(try HealRules.mask(CoverageGrid.empty, width: 8, height: 6).area == 0)
    }
}
