// VectorRasterizerTests.swift: the suite's one vector draw-list rasterizer (#5079). A 60 × 30 point sheet holds
// one mark per feature: a solid fill, a stroke, a linear gradient, a clipped fill, a half-opaque fill and a line of
// text. At 1x and 2x each lands on known pixels. The image is 8-bit sRGB with premultiplied alpha; its PNG decodes
// back to the same pixels; two runs give the same bytes; and the 2x sheet is held by a golden (recorded on CI, as
// Golden/README.md says). A bad size throws `invalidSize`. macOS only.
#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import SuiteKernel
import SuiteModel
import SuiteShell
import SuiteUI
import Testing

@Suite struct VectorRasterizerTests {
    private static func rect(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> VectorPath {
        VectorPath(polyline: [Point(x: x0, y: y0), Point(x: x1, y: y0), Point(x: x1, y: y1), Point(x: x0, y: y1)],
                   closed: true)
    }

    private static let red = FillColor(r: 1, g: 0, b: 0), blue = FillColor(r: 0, g: 0, b: 1)
    private static let black = FillColor(r: 0, g: 0, b: 0), white = FillColor(r: 1, g: 1, b: 1)

    /// The sheet, in points, y down: fill, stroke and opacity on the top row; gradient, clip and text below.
    static func sheet(background: FillColor? = white) -> VectorDrawList {
        let gradient = Fill.linear(stops: [GradientStop(offset: 0, color: black), GradientStop(offset: 1, color: white)],
                                   start: Point(x: 2, y: 0), end: Point(x: 18, y: 0))
        let text = PlacedSpan(span: TextSpan("W", fontSize: 14), origins: [SuitePoint(x: 43, y: 27)], degrees: [0])
        return VectorDrawList(width: 60, height: 30, background: background, items: [
            VectorDrawItem(path: rect(2, 2, 18, 12), fill: .solid(red)),
            VectorDrawItem(path: rect(24, 4, 36, 10), stroke: VectorStroke(color: blue, width: 2)),
            VectorDrawItem(path: rect(42, 2, 58, 12), fill: .solid(black), opacity: 0.5),
            VectorDrawItem(path: rect(2, 16, 18, 28), fill: gradient),
            VectorDrawItem(path: rect(22, 16, 38, 28), fill: .solid(blue), clip: rect(22, 16, 30, 28)),
            VectorDrawItem(text: text),
        ])
    }

    private static func pixels(_ image: CGImage) throws -> RGBAImage { try #require(RGBAImage(cgImage: image)) }

    private func pixel(_ image: RGBAImage, _ x: Int, _ y: Int) -> [Int] {
        let at = (y * image.width + x) * 4
        guard at >= 0, at + 4 <= image.bytes.count else { return [] }
        return image.bytes[at..<at + 4].map(Int.init)
    }

    private func near(_ got: [Int], _ want: [Int], within: Int = 2) -> Bool {
        got.count == want.count && zip(got, want).allSatisfy { abs($0 - $1) <= within }
    }

    @Test(arguments: [1.0, 2.0]) func eachMarkLandsOnItsPixels(scale: Double) throws {
        let image = try Self.pixels(try VectorRasterizer().image(Self.sheet(), scale: scale))
        let s = Int(scale)
        #expect(image.width == 60 * s && image.height == 30 * s)
        func at(_ x: Double, _ y: Double) -> [Int] { pixel(image, Int(x * scale), Int(y * scale)) }
        #expect(at(10, 7) == [255, 0, 0, 255], "the solid fill")
        #expect(at(30, 4) == [0, 0, 255, 255], "the stroke, on the edge")
        #expect(at(30, 7) == [255, 255, 255, 255], "inside the stroke, unfilled")
        #expect(near(at(50, 7), [128, 128, 128, 255]), "half-opaque black over white: \(at(50, 7))")
        let (dark, mid, light) = (at(3, 22)[0], at(10, 22)[0], at(17, 22)[0])
        #expect(dark < mid && mid < light && abs(mid - 128) <= 12, "the gradient runs dark to light: \(dark) \(mid) \(light)")
        #expect(at(26, 22) == [0, 0, 255, 255], "the clipped fill, inside its clip")
        #expect(at(34, 22) == [255, 255, 255, 255], "the clipped fill, cut off past its clip")
        let ink = (17 * s..<28 * s).flatMap { y in (42 * s..<58 * s).map { pixel(image, $0, y)[0] } }
        #expect(ink.min() ?? 255 < 64, "the text inks its box")
        #expect(at(59, 29) == [255, 255, 255, 255], "the corner holds the background")
    }

    @Test func itIsEightBitSRGBPremultiplied() throws {
        let image = try VectorRasterizer().image(Self.sheet(), scale: 1)
        #expect(image.colorSpace?.name == CGColorSpace.sRGB)
        #expect(image.bitsPerComponent == 8 && image.bitsPerPixel == 32)
        #expect(image.alphaInfo == .premultipliedLast)
    }

    @Test func noBackgroundLeavesTheCanvasClear() throws {
        let image = try Self.pixels(try VectorRasterizer().image(Self.sheet(background: nil), scale: 1))
        #expect(pixel(image, 59, 29) == [0, 0, 0, 0])
        #expect(pixel(image, 10, 7) == [255, 0, 0, 255])
    }

    @Test func itsPNGRoundTripsToTheSamePixels() throws {
        let rasterizer = VectorRasterizer()
        let png = try rasterizer.png(Self.sheet(), scale: 2)
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]), "a PNG signature")
        let decoded = try #require(RGBAImage(png: png))
        let drawn = try Self.pixels(try rasterizer.image(Self.sheet(), scale: 2))
        #expect(decoded.width == 120 && decoded.height == 60)
        #expect(decoded.bytes == drawn.bytes)
    }

    @Test func twoRunsGiveTheSameBytes() throws {
        let rasterizer = VectorRasterizer()
        #expect(try rasterizer.png(Self.sheet(), scale: 2) == rasterizer.png(Self.sheet(), scale: 2))
        let first = try Self.pixels(try rasterizer.image(Self.sheet(), scale: 2))
        #expect(first.bytes == (try Self.pixels(try rasterizer.image(Self.sheet(), scale: 2))).bytes)
    }

    @Test func theTwoXSheetMatchesTheGolden() throws {
        let image = try Self.pixels(try VectorRasterizer().image(Self.sheet(), scale: 2))
        assertGolden(image, name: "vector-raster-sheet", area: "suite", appearance: "light")
    }

    @Test func aBadSizeThrows() {
        let empty = VectorDrawList(width: 0, height: 10, background: nil, items: [])
        let huge = VectorDrawList(width: 20_000, height: 10, background: nil, items: [])
        #expect(throws: VectorRasterError.invalidSize) { try VectorRasterizer().image(empty, scale: 1) }
        #expect(throws: VectorRasterError.invalidSize) { try VectorRasterizer().image(huge, scale: 1) }
        #expect(throws: VectorRasterError.invalidSize) { try VectorRasterizer().image(Self.sheet(), scale: .nan) }
    }
}
#endif
