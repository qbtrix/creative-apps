// CanvasMotionMarksTests.swift: MotionPathMarks and GhostLayer
// (CanvasMarks+Motion.swift). The motion path puts one dot per frame point,
// centred on it at the zoom and the same size at every zoom, in its geometry
// and in the pixels it draws; points that aren't finite are dropped and a bad
// zoom counts as 1. The ghost draws its content at its opacity, clamped to
// 0...1 with NaN as 0. Both take no hit and are hidden from accessibility
// (#273). macOS only.
import CoreGraphics
import SuiteUI
import SwiftUI
import Testing

@Test func theMotionPathPutsOneFixedSizeDotOnEachFramePoint() {
    let points = [CGPoint(x: 10, y: 5), CGPoint(x: 20, y: 15), CGPoint(x: 40, y: 10)]
    let one = MotionPathMarks.dots(points: points, zoom: 1)
    let four = MotionPathMarks.dots(points: points, zoom: 4)
    #expect(one.count == points.count && four.count == points.count)
    #expect(one.allSatisfy { $0.size == CGSize(width: SuiteSize.anchor, height: SuiteSize.anchor) })
    #expect(four.map(\.size) == one.map(\.size))
    #expect(one.map { CGPoint(x: $0.midX, y: $0.midY) } == points)
    #expect(four.map { CGPoint(x: $0.midX, y: $0.midY) } == [CGPoint(x: 40, y: 20), CGPoint(x: 80, y: 60), CGPoint(x: 160, y: 40)])
}

@Test func theMotionPathDropsPointsThatAreNotFiniteAndReadsABadZoomAsOne() {
    let points = [CGPoint(x: 3, y: 4), CGPoint(x: CGFloat.nan, y: 1), CGPoint(x: 1, y: CGFloat.infinity), CGPoint(x: 6, y: 8)]
    #expect(MotionPathMarks.line(points: points, zoom: 2) == [CGPoint(x: 6, y: 8), CGPoint(x: 12, y: 16)])
    for zoom in [0, -2, Double.nan, .infinity] {
        #expect(MotionPathMarks.scale(zoom) == 1)
        #expect(MotionPathMarks.line(points: points, zoom: zoom) == [CGPoint(x: 3, y: 4), CGPoint(x: 6, y: 8)])
    }
    #expect(MotionPathMarks.dots(points: [], zoom: 1).isEmpty)
}

@Test func theMotionMarksTakeNoHitAndAreHidden() {
    #expect(!MotionPathMarks.takesHits)
    #expect(MotionPathMarks.hiddenFromAccessibility)
}

@MainActor @Test func theGhostKeepsItsOpacityInZeroToOne() {
    #expect(GhostLayer(content: Color.clear, opacity: 0.4).opacity == 0.4)
    #expect(GhostLayer<Color>.clamped(-1) == 0 && GhostLayer<Color>.clamped(2) == 1)
    #expect(GhostLayer<Color>.clamped(.nan) == 0 && GhostLayer<Color>.clamped(.infinity) == 1)
}

/// Each frame point gets a dot: the pixel under it is marked, and the pixel
/// in the middle of the square the path runs round is not.
@MainActor @Test func theMotionPathDrawsADotOnEveryFramePoint() throws {
    let points = [CGPoint(x: 5, y: 5), CGPoint(x: 25, y: 5), CGPoint(x: 25, y: 25), CGPoint(x: 5, y: 25)]
    let view = ZStack { SuiteColor.overlayPaper; MotionPathMarks(points: points, zoom: 2) }
        .frame(width: 60, height: 60)
    let image = try rendered(view)
    for point in points {
        let red = try #require(redChannel(image, x: Int(point.x * 2), y: Int(point.y * 2)))
        #expect(red < 215, "no dot at \(point)")
    }
    #expect(redChannel(image, x: 30, y: 30) == 255)
}

/// Black at opacity 0, 0.5 and 1 over white reads white, mid grey and black.
@MainActor @Test(arguments: zip([0.0, 0.5, 1.0], [255, 128, 0]))
func theGhostDrawsAtItsOpacity(_ opacity: Double, _ expected: Int) throws {
    let view = ZStack { SuiteColor.overlayPaper; GhostLayer(content: SuiteColor.overlayInk, opacity: opacity) }
        .frame(width: 20, height: 20)
    let red = try #require(redChannel(try rendered(view), x: 10, y: 10))
    #expect(abs(red - expected) <= 12, "opacity \(opacity) drew \(red)")
}

@MainActor private func rendered(_ view: some View) throws -> CGImage {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    return try #require(renderer.cgImage)
}

/// The red channel of the pixel at (`x`, `y`), top-left origin, or nil.
private func redChannel(_ image: CGImage, x: Int, y: Int) -> Int? {
    let width = image.width, height = image.height
    guard x >= 0, y >= 0, x < width, y < height, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    return drawn ? Int(bytes[(y * width + x) * 4]) : nil
}
