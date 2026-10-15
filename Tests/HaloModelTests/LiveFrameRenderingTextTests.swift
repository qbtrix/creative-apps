// LiveFrameRenderingTextTests.swift: VP-5, text pixels in the live renderer
// on a 400 x 200 composition. "Hi" at 50 measures 60 x 50, centered at
// (200, 100), so its box is 170...230 by 75...125. The raster is resized by
// the item's scale, turned by its rotation about its center and composited
// at its world center; the raster's top-left is the item's bounds.origin, so
// its baseline row sits at height - descent. Runs on Linux and macOS.
import CoreRaster
import FlareCore
import HaloModel
import Testing

private let red = HaloLayerColor(red: 1, green: 0, blue: 0)
private let hi = HaloTextContent(string: "Hi", fontSize: 50)
private let box = HaloLayerRect(x: 170, y: 75, width: 60, height: 50)

/// The "Hi" item, its matrix `inner` applied about the box's center.
private func textItem(_ inner: HaloMatrix = .identity) -> HaloDrawItem {
    let m = HaloMatrix.translation(x: 200, y: 100) * inner * HaloMatrix.translation(x: -200, y: -100)
    return HaloDrawItem(
        layerID: "t", kind: .text, bounds: box, matrix: m, opacity: 1, color: red, blendMode: .normal, text: hi)
}

private func render(
    _ item: HaloDrawItem, width: Int = 400, height: Int = 200,
    text: (any TextRasterizing)? = FakeTextRasterizer()
) throws -> HaloRenderedFrame {
    try LiveFrameRendering().render(
        HaloDrawList(width: 400, height: 200, frame: 0, items: [item]), width: width, height: height, text: text)
}

private func covered(_ pixels: PixelBuffer, _ x: Int, _ y: Int) throws -> Bool {
    try pixels.pixel(x: x, y: y).a > 0.5
}

/// The covered rows and columns of `pixels`: (minX, maxX, minY, maxY).
private func extent(_ pixels: PixelBuffer) throws -> (Int, Int, Int, Int)? {
    var result: (Int, Int, Int, Int)?
    for y in 0..<pixels.height {
        for x in 0..<pixels.width where try covered(pixels, x, y) {
            let r = result ?? (x, x, y, y)
            result = (min(r.0, x), max(r.1, x), min(r.2, y), max(r.3, y))
        }
    }
    return result
}

/// A 60 x 50 line box, ascent 40 and descent 10, that draws only its top-left
/// pixel and its baseline row (y = height - descent).
private struct BaselineRasterizer: TextRasterizing {
    func measure(_ text: HaloTextContent) -> HaloLayerRect { HaloLayerRect(x: 0, y: 0, width: 60, height: 50) }
    func rasterize(_ text: HaloTextContent, color: HaloLayerColor) throws -> PixelBuffer {
        var buffer = try PixelBuffer(width: 60, height: 50)
        let ink = RGBA(r: 1, g: 0, b: 0, a: 1)
        try buffer.setPixel(x: 0, y: 0, ink)
        for x in 10..<60 { try buffer.setPixel(x: x, y: 50 - 10, ink) }
        return buffer
    }
}

@Test func textAtFullSizeFillsItsBoxInTheLayerColor() throws {
    let frame = try render(textItem())
    let p = try frame.pixels.pixel(x: 200, y: 100)
    #expect(p.r == 1 && p.g == 0 && p.b == 0 && p.a == 1)
    #expect(try frame.pixels.pixel(x: 165, y: 100).a == 0)
    #expect(try extent(frame.pixels) ?? (0, 0, 0, 0) == (170, 229, 75, 124))
    #expect(frame.skippedLayerCount == 0)
}

@Test func textAtHalfRenderSizeHalvesItsBox() throws {
    let frame = try render(textItem(), width: 200, height: 100)
    // 85...115 by 37.5...62.5, the top edge rounded to row 38.
    #expect(try extent(frame.pixels) ?? (0, 0, 0, 0) == (85, 114, 38, 62))
    #expect(frame.skippedLayerCount == 0)
}

@Test func textRotated90DegreesTurnsItsBoxAboutItsCenter() throws {
    let frame = try render(textItem(.rotation(degrees: 90)))
    #expect(try covered(frame.pixels, 200, 72))
    #expect(try !covered(frame.pixels, 172, 100))
    #expect(try extent(frame.pixels) ?? (0, 0, 0, 0) == (175, 224, 70, 129))
}

@Test func textAtScale2DoublesItsBox() throws {
    let frame = try render(textItem(.scale(x: 2, y: 2)))
    #expect(try extent(frame.pixels) ?? (0, 0, 0, 0) == (140, 259, 50, 149))
}

@Test func theRastersTopLeftIsTheBoundsOriginAndItsBaselineSitsAboveTheDescent() throws {
    let frame = try render(textItem(), text: BaselineRasterizer())
    #expect(try covered(frame.pixels, 170, 75))
    #expect(try !covered(frame.pixels, 171, 75))
    // Baseline row at origin + 50 - 10.
    #expect(try covered(frame.pixels, 200, 115))
    #expect(try !covered(frame.pixels, 200, 114))
    #expect(try !covered(frame.pixels, 200, 116))
}

@Test func withNoRasterizerTextIsNotDrawnAndCounted() throws {
    let frame = try render(textItem(), text: nil)
    #expect(try extent(frame.pixels) == nil)
    #expect(frame.skippedLayerCount == 1)
}

@Test func aMirroredTextIsSkippedAndCounted() throws {
    let frame = try render(textItem(.scale(x: -1, y: 1)))
    #expect(try extent(frame.pixels) == nil)
    #expect(frame.skippedLayerCount == 1)
}
