// PhotoDraftHalvingTests.swift: a shrinking Free Transform draft halves its layer once per level
// (`PhotoWorkspace.halvedAcrossCores`, PhotoRenderRoute.swift) tile by tile across the cores. These
// hold it to CoreRaster's own whole-buffer bilinear halving bit for bit: odd sizes, a buffer wider
// and taller than one output tile (so tile seams are inside), and the 1 px edge cases. The 24 MP
// timing lives in PhotoDraftHalvingBudgetTests. Runs on Linux and macOS.
import CoreRaster
import Testing

@testable import PhotoModel

@Suite struct PhotoDraftHalvingTests {
    /// A `width` x `height` buffer whose every pixel differs from its neighbours.
    static func pattern(_ width: Int, _ height: Int) throws -> PixelBuffer {
        var b = try PixelBuffer(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                let a = Float((x * 7 + y * 13) % 17) / 16
                try b.setPixel(x: x, y: y, RGBA(r: Float((x * 31 + y) % 23) / 22 * a, g: Float((x + y * 29) % 19) / 18 * a,
                                                b: Float((x * y) % 11) / 10 * a, a: a))
            }
        }
        return b
    }

    @Test(arguments: [(1, 1), (2, 3), (1, 600), (517, 301), (1027, 513)])
    func halvesLikeCoreRasterBitForBit(size: (Int, Int)) throws {
        let source = try Self.pattern(size.0, size.1)
        let want = try source.transformed(AffineMatrix(a: 0.5, b: 0, c: 0, d: 0.5, tx: 0, ty: 0),
                                          width: (size.0 + 1) / 2, height: (size.1 + 1) / 2, filter: .bilinear)
        let got = try PhotoWorkspace.halvedAcrossCores(source)
        #expect(got == want, "\(size.0) x \(size.1): the tiled halving differs from CoreRaster's")
    }
}
