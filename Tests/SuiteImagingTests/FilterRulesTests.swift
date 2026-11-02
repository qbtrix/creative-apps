// FilterRulesTests.swift (adjust-everywhere AJ-1 written disabled, AJ-5f turns
// it on): the five filters over creative-core inside a selection's coverage.
// Pixels outside the coverage are unchanged byte for byte; blur radius 0 is
// the input; a blur inside the selection still reads the pixels past its
// bounds; Add Noise with one seed is the same twice and differs with another;
// a preview's longest side is 1024. Mutations (AJ-5f): SuiteImaging.FilterRules
// (`.outsideUnchanged`, `.noiseIsSeeded`, `.blurReachesPastBounds`).
import CoreRaster
import Testing
import SuiteImaging

@Suite struct FilterRulesTests {
    static let black = RGBA(r: 0, g: 0, b: 0, a: 1), white = RGBA(r: 1, g: 1, b: 1, a: 1)
    /// One of each filter, strong enough to change every covered pixel of `checks`.
    static let filters: [ImagingFilter] = [
        .gaussianBlur(radius: 3), .motionBlur(degrees: 30, distance: 8), .sharpen(amount: 300, radius: 2, threshold: 0),
        .reduceNoise(strength: 100, detail: 0), .addNoise(amount: 50, monochrome: false, seed: 7),
    ]

    /// 16 x 16 checks of 2 x 2 pixels, grey levels varying by position.
    static func checks() throws -> PixelBuffer {
        var p = try PixelBuffer(width: 16, height: 16)
        for y in 0..<16 {
            for x in 0..<16 {
                let v: Float = (x / 2 + y / 2) % 2 == 0 ? 0.2 + Float(x) / 40 : 0.8 - Float(y) / 40
                try p.setPixel(x: x, y: y, RGBA(r: v, g: v * 0.9, b: v * 0.8, a: 1))
            }
        }
        return p
    }

    /// The left half (x 0..<8) covered.
    static func leftHalf(_ width: Int = 16, _ height: Int = 16) throws -> Mask {
        try Mask.rectangle(width: width, height: height, x: 0, y: 0, w: Double(width / 2), h: Double(height))
    }

    /// Every pixel with x in `columns` is equal in both buffers.
    static func same(_ a: PixelBuffer, _ b: PixelBuffer, columns: Range<Int>) throws -> Bool {
        for y in 0..<a.height { for x in columns where try a.pixel(x: x, y: y) != b.pixel(x: x, y: y) { return false } }
        return true
    }

    /// Each filter changes the covered half and leaves the other half byte for byte.
    @Test func outsideUnchanged() throws {
        let p = try Self.checks(), half = try Self.leftHalf()
        for f in Self.filters {
            let out = try FilterRules.apply(f, to: p, coverage: half)
            #expect(try Self.same(p, out, columns: 8..<16), "\(f.id)")
            #expect(try !Self.same(p, out, columns: 0..<8), "\(f.id)")
        }
        let everywhere = try FilterRules.apply(.gaussianBlur(radius: 3), to: p, coverage: nil)
        #expect(try !Self.same(p, everywhere, columns: 8..<16))
    }

    @Test func zeroIsInput() throws {
        let p = try Self.checks()
        #expect(try FilterRules.apply(.gaussianBlur(radius: 0), to: p, coverage: nil) == p)
        #expect(try FilterRules.apply(.addNoise(amount: 0, monochrome: true, seed: 3), to: p, coverage: nil) == p)
    }

    /// The same seed gives the same noise; another seed different noise; monochrome keeps r = g = b on grey.
    @Test func noiseIsSeeded() throws {
        let grey = try PixelBuffer(width: 8, height: 8, fill: RGBA(r: 0.5, g: 0.5, b: 0.5, a: 1))
        let a = try FilterRules.apply(.addNoise(amount: 30, monochrome: false, seed: 1), to: grey, coverage: nil)
        let b = try FilterRules.apply(.addNoise(amount: 30, monochrome: false, seed: 1), to: grey, coverage: nil)
        let c = try FilterRules.apply(.addNoise(amount: 30, monochrome: false, seed: 2), to: grey, coverage: nil)
        #expect(a == b && a != c && a != grey)
        let mono = try FilterRules.apply(.addNoise(amount: 30, monochrome: true, seed: 1), to: grey, coverage: nil)
        for y in 0..<8 { for x in 0..<8 { let q = try mono.pixel(x: x, y: y); #expect(q.r == q.g && q.g == q.b) } }
    }

    /// Black covered on the left, white uncovered on the right: the blur still pulls white in at the edge.
    @Test func blurReachesPastBounds() throws {
        var p = try PixelBuffer(width: 16, height: 4, fill: Self.black)
        for y in 0..<4 { for x in 8..<16 { try p.setPixel(x: x, y: y, Self.white) } }
        let out = try FilterRules.apply(.gaussianBlur(radius: 2), to: p, coverage: Self.leftHalf(16, 4))
        #expect(try out.pixel(x: 7, y: 2).r > 0.1)
        #expect(try out.pixel(x: 8, y: 2) == Self.white)
    }

    /// The preview is at most 1024 on its longest side, keeping the aspect; a small picture keeps its size.
    @Test func previewLongestSide() throws {
        let wide = try PixelBuffer(width: 2048, height: 512, fill: Self.white)
        let out = try FilterRules.preview(.gaussianBlur(radius: 4), to: wide, coverage: nil, longestSide: FilterRules.previewSide)
        #expect(out.width == 1024 && out.height == 256)
        let small = try Self.checks()
        #expect(try FilterRules.preview(.gaussianBlur(radius: 1), to: small, coverage: Self.leftHalf(), longestSide: 1024).width == 16)
    }
}
