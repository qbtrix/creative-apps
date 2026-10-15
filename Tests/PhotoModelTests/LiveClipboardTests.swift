// LiveClipboardTests.swift: E-1, the live clipboard. Copy cuts to what is not
// transparent and sets `source`, weights by the mask, and gives nil for a
// transparent area; placement keeps an overlapping source and otherwise
// centers on the view, never wholly off the canvas. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct LiveClipboardTests {
    let clipboard = PhotoServices.live.clipboard
    let red = RGBA(r: 1, g: 0, b: 0, a: 1)

    /// A 300 x 280 clear layer at (10, 20) with an opaque red block at layer
    /// pixels 250..<270 x 40..<60, so it crosses a tile edge (256).
    private func layer() throws -> PlacedPixels {
        var buffer = try PixelBuffer(width: 300, height: 280)
        for y in 40..<60 { for x in 250..<270 { try buffer.setPixel(x: x, y: y, red) } }
        return PlacedPixels(pixels: TiledPixels(buffer), x: 10, y: 20)
    }

    private func alphas(_ image: DecodedImage) -> [UInt8] {
        stride(from: 3, to: image.rgba8.count, by: 4).map { image.rgba8[$0] }
    }

    @Test func helpIsNil() {
        #expect(clipboard.unavailableHelp == nil)
    }

    @Test func copyTrimsToTheOpaquePartAndSetsSource() throws {
        let selection = PixelRect(x: 200, y: 30, width: 150, height: 100)
        let copied = try #require(try clipboard.copy(layer(), selection: selection, mask: nil))
        #expect(copied.source == PixelRect(x: 260, y: 60, width: 20, height: 20))
        #expect(copied.image.width == 20 && copied.image.height == 20)
        #expect(copied.image.rgba8.count == 20 * 20 * 4)
        #expect(Array(copied.image.rgba8.prefix(4)) == [255, 0, 0, 255])
        #expect(alphas(copied.image).allSatisfy { $0 == 255 })
    }

    @Test func noSelectionCopiesTheWholeLayerTrimmed() throws {
        let copied = try #require(try clipboard.copy(layer(), selection: nil, mask: nil))
        #expect(copied.source == PixelRect(x: 260, y: 60, width: 20, height: 20))
    }

    @Test func selectionIsClippedToTheContent() throws {
        let selection = PixelRect(x: 270, y: 70, width: 500, height: 500)
        let copied = try #require(try clipboard.copy(layer(), selection: selection, mask: nil))
        #expect(copied.source == PixelRect(x: 270, y: 70, width: 10, height: 10))
    }

    @Test func halfCoverageMaskHalvesAlpha() throws {
        let mask = try Mask(width: 400, height: 400, fill: 0.5)
        let copied = try #require(try clipboard.copy(layer(), selection: nil, mask: mask))
        #expect(copied.source == PixelRect(x: 260, y: 60, width: 20, height: 20))
        #expect(alphas(copied.image).allSatisfy { (127...128).contains($0) })
        #expect(Array(copied.image.rgba8.prefix(3)) == [255, 0, 0])
    }

    @Test func maskTrimsToItsCoverage() throws {
        let mask = try Mask.rectangle(width: 400, height: 400, x: 265, y: 65, w: 5, h: 5)
        let copied = try #require(try clipboard.copy(layer(), selection: nil, mask: mask))
        #expect(copied.source == PixelRect(x: 265, y: 65, width: 5, height: 5))
    }

    @Test func transparentAreaGivesNil() throws {
        let content = try layer()
        #expect(try clipboard.copy(content, selection: PixelRect(x: 10, y: 20, width: 50, height: 50), mask: nil) == nil)
        #expect(try clipboard.copy(content, selection: PixelRect(x: 900, y: 900, width: 5, height: 5), mask: nil) == nil)
        let empty = try Mask(width: 400, height: 400)
        #expect(try clipboard.copy(content, selection: nil, mask: empty) == nil)
    }

    private func image(_ width: Int, _ height: Int, source: PixelRect?) -> ClipboardImage {
        ClipboardImage(
            image: DecodedImage(rgba8: [UInt8](repeating: 255, count: width * height * 4), width: width, height: height),
            source: source)
    }

    @Test func placementKeepsAnOverlappingSource() {
        let canvas = CanvasSize(width: 100, height: 80)
        let source = PixelRect(x: 90, y: -5, width: 30, height: 20)
        let rect = clipboard.placement(of: image(30, 20, source: source), canvas: canvas, center: .init(x: 10, y: 10))
        #expect(rect == source)
    }

    @Test func placementCentersANilSourceOnCenter() {
        let canvas = CanvasSize(width: 100, height: 80)
        let rect = clipboard.placement(of: image(30, 20, source: nil), canvas: canvas, center: .init(x: 40, y: 30))
        #expect(rect == PixelRect(x: 25, y: 20, width: 30, height: 20))
    }

    @Test func sourceOffTheCanvasIsCenteredOnIt() {
        let canvas = CanvasSize(width: 100, height: 80)
        let off = PixelRect(x: 500, y: 500, width: 30, height: 20)
        let rect = clipboard.placement(of: image(30, 20, source: off), canvas: canvas, center: .init(x: 50, y: 40))
        #expect(rect == PixelRect(x: 35, y: 30, width: 30, height: 20))
        #expect(rect.intersection(canvas.rect) != nil)
    }

    @Test func placementNeverLeavesTheCanvas() {
        let canvas = CanvasSize(width: 100, height: 80)
        let centers = [Mask.Point(x: 1e12, y: -1e12), .init(x: -500, y: 900), .init(x: .nan, y: .infinity)]
        for center in centers {
            let rect = clipboard.placement(of: image(30, 20, source: nil), canvas: canvas, center: center)
            #expect(rect.intersection(canvas.rect) != nil, "\(center)")
        }
    }
}
