// HaloTextRasterizerTests.swift: TX-4 of text-layers (#430). HaloApp's Core
// Text rasterizer measures a whole-pixel typographic line box at the origin,
// rasterizes into a buffer exactly that size, in linear light and
// premultiplied, with the glyphs' image bounds inside the box (baseline at
// height - descent from the top). macOS only.
import CoreGraphics
import CoreRaster
import CoreText
import Foundation
import HaloModel
import Testing

@testable import HaloApp

@Suite struct HaloTextRasterizerTests {
    private let rasterizer = HaloTextRasterizer()
    private static let white = HaloLayerColor(red: 1, green: 1, blue: 1)

    @Test func measureIsAWholePixelBoxAtTheOrigin() {
        let box = rasterizer.measure(HaloTextContent(string: "Hello", fontSize: 96))
        #expect(box.x == 0)
        #expect(box.y == 0)
        #expect(box.width > 0)
        #expect(box.width == box.width.rounded())
        #expect(box.height == box.height.rounded())
        #expect(box.height >= 96)
        #expect(box.height < 160)
    }

    @Test func widthGrowsWithTheString() {
        let short = rasterizer.measure(HaloTextContent(string: "Hello", fontSize: 96))
        let long = rasterizer.measure(HaloTextContent(string: "Hello Halo", fontSize: 96))
        #expect(long.width > short.width)
        #expect(long.height == short.height)
    }

    @Test(arguments: [("Hello", 96.0), ("Hello Halo", 12.0), ("Ågy", 400.0), ("", 72.0)])
    func bufferIsExactlyTheBox(string: String, size: Double) throws {
        let text = HaloTextContent(string: string, fontSize: size)
        let box = rasterizer.measure(text)
        let pixels = try rasterizer.rasterize(text, color: Self.white)
        #expect(Double(pixels.width) == box.width)
        #expect(Double(pixels.height) == box.height)
    }

    @Test func whiteHelloHasInkInBothOuterQuarters() throws {
        let pixels = try rasterizer.rasterize(HaloTextContent(string: "Hello", fontSize: 96), color: Self.white)
        let quarter = pixels.width / 4
        #expect(quarter > 0)
        #expect(try hasInk(pixels, columns: 0..<quarter))
        #expect(try hasInk(pixels, columns: (pixels.width - quarter)..<pixels.width))
    }

    @Test func pixelsAreLinearAndPremultiplied() throws {
        let orange = HaloLayerColor(red: 1, green: 0.5, blue: 0)
        let pixels = try rasterizer.rasterize(HaloTextContent(string: "Hello", fontSize: 200), color: orange)
        let all = try (0..<pixels.height).flatMap { y in try (0..<pixels.width).map { try pixels.pixel(x: $0, y: y) } }
        let tolerance: Float = 1 / 255
        // sRGB 0.5 decoded with the sRGB transfer curve.
        let linearHalf = Float(pow((0.5 + 0.055) / 1.055, 2.4))
        let covered = try #require(all.first(where: { $0.a >= 0.9999 }))
        #expect(abs(covered.r - 1) <= tolerance)
        #expect(abs(covered.g - linearHalf) <= tolerance)
        #expect(abs(covered.b) <= tolerance)
        #expect(abs(covered.a - 1) <= tolerance)
        let edge = try #require(all.first(where: { $0.a > 0.3 && $0.a < 0.7 }))
        #expect(edge.r <= edge.a + 1e-5)
        #expect(edge.g <= edge.a + 1e-5)
        #expect(edge.b <= edge.a + 1e-5)
    }

    @Test(arguments: ["Wj", "Ågy", "—"], [12.0, 96.0, 400.0])
    func imageBoundsLieInsideTheBox(string: String, size: Double) throws {
        let text = HaloTextContent(string: string, fontSize: size)
        let box = rasterizer.measure(text)
        let ink = try imageBounds(text)
        #expect(ink.minX >= -1)
        #expect(ink.maxX <= box.width + 1)
        #expect(ink.minY >= -1)
        #expect(ink.maxY <= box.height + 1)
    }

    @Test func drawnInkSitsWhereTheImageBoundsSay() throws {
        let text = HaloTextContent(string: "Hello", fontSize: 96)
        let pixels = try rasterizer.rasterize(text, color: Self.white)
        let expected = try imageBounds(text)
        var top = pixels.height, bottom = -1, left = pixels.width, right = -1
        for y in 0..<pixels.height {
            for x in 0..<pixels.width {
                guard try pixels.pixel(x: x, y: y).a > 0.02 else { continue }
                top = min(top, y); bottom = max(bottom, y); left = min(left, x); right = max(right, x)
            }
        }
        #expect(bottom >= top)
        // Rows count from the top; the image bounds are y-up from the box's bottom.
        #expect(abs(Double(top) - (Double(pixels.height) - expected.maxY)) <= 2)
        #expect(abs(Double(bottom + 1) - (Double(pixels.height) - expected.minY)) <= 2)
        #expect(abs(Double(left) - expected.minX) <= 2)
        #expect(abs(Double(right + 1) - expected.maxX) <= 2)
    }

    /// Whether some pixel in `columns` has alpha over 0.5.
    private func hasInk(_ pixels: PixelBuffer, columns: Range<Int>) throws -> Bool {
        for y in 0..<pixels.height {
            for x in columns {
                if try pixels.pixel(x: x, y: y).a > 0.5 { return true }
            }
        }
        return false
    }

    /// `CTLineGetImageBounds` of the rasterizer's line, moved into the box's
    /// y-up space: the baseline `descent` above the box's bottom.
    private func imageBounds(_ text: HaloTextContent) throws -> CGRect {
        let layout = HaloTextRasterizer.layout(text, color: nil)
        let line = try #require(layout.line)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)))
        context.textMatrix = .identity
        context.textPosition = .zero
        let bounds = CTLineGetImageBounds(line, context)
        #expect(!bounds.isNull)
        return bounds.offsetBy(dx: 0, dy: layout.descent)
    }
}
