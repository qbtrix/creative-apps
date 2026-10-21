// LiveTransformTests.swift: Photo's live transform on CoreRaster and the
// kernel's TransformRules (transform PT-4). Commit resamples once through
// `TransformRules.matrix`; the identity gives the layer back bit for bit, a
// quarter turn lands every pixel where the turn puts it, a flip mirrors
// exactly and twice is the input, and the draft's corners are the kernel's.
// Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct LiveTransformTests {
    private let live = PhotoServices.live.transform

    /// A `width` x `height` layer at (`x`, `y`) whose every pixel differs
    /// from every other, so a wrong turn or flip shows.
    private func layer(_ width: Int, _ height: Int, x: Int = 0, y: Int = 0) throws -> PlacedPixels {
        var buffer = try PixelBuffer(width: width, height: height)
        for py in 0..<height {
            for px in 0..<width {
                let r = Float(px + 1) / Float(width + 1), g = Float(py + 1) / Float(height + 1)
                try buffer.setPixel(x: px, y: py, RGBA(r: r, g: g, b: 0.25, a: 1))
            }
        }
        return PlacedPixels(pixels: TiledPixels(buffer), x: x, y: y)
    }

    private func draft(_ content: PlacedPixels, _ transform: PhotoModel.LayerTransform = .identity) -> TransformDraft {
        TransformDraft(layerID: "layer-1", box: PixelRect(x: content.x, y: content.y, width: content.pixels.width,
                                                          height: content.pixels.height), transform: transform)
    }

    @Test func helpIsNil() {
        #expect(live.unavailableHelp == nil)
    }

    @Test func theIdentityCommitGivesTheLayerBack() throws {
        let content = try layer(5, 3, x: 7, y: -2)
        let out = try live.applied(draft(content), to: content)
        #expect(out == content)
        #expect(try out.pixels.flattened() == content.pixels.flattened())
    }

    @Test func turn90Size() throws {
        let content = try layer(4, 2)
        let out = try live.applied(draft(content, PhotoModel.LayerTransform(degrees: 90)), to: content)
        #expect(out.pixels.width == 2 && out.pixels.height == 4)
        // Turned clockwise about the box's centre (2, 1): the box is x 1..<3, y -1..<3.
        #expect(out.x == 1 && out.y == -1)
        let source = try content.pixels.flattened(), turned = try out.pixels.flattened()
        for y in 0..<2 {
            for x in 0..<4 {
                // Clockwise: source (x, y) lands at (height - 1 - y, x).
                #expect(try turned.pixel(x: 1 - y, y: x) == source.pixel(x: x, y: y), "\(x),\(y)")
            }
        }
    }

    @Test func flipHorizontal() throws {
        let content = try layer(4, 3, x: 2, y: 5)
        let source = try content.pixels.flattened()
        let across = try live.flipped(content, .horizontal), down = try live.flipped(content, .vertical)
        #expect(across.x == 2 && across.y == 5 && down.x == 2 && down.y == 5)
        let a = try across.pixels.flattened(), d = try down.pixels.flattened()
        for y in 0..<3 {
            for x in 0..<4 {
                #expect(try a.pixel(x: 3 - x, y: y) == source.pixel(x: x, y: y), "\(x),\(y)")
                #expect(try d.pixel(x: x, y: 2 - y) == source.pixel(x: x, y: y), "\(x),\(y)")
            }
        }
    }

    @Test func flippingTwiceGivesTheInput() throws {
        let content = try layer(5, 4, x: 3, y: 1)
        for axis in FlipAxis.allCases {
            let twice = try live.flipped(live.flipped(content, axis), axis)
            #expect(try twice.pixels.flattened() == content.pixels.flattened())
            #expect(twice.x == content.x && twice.y == content.y)
        }
    }

    @Test func theDraftsCornersAreTheKernels() {
        let t = PhotoModel.LayerTransform(scaleX: 1.5, scaleY: 0.5, degrees: 30, dx: 4, dy: -6)
        let d = TransformDraft(layerID: "layer-1", box: PixelRect(x: 10, y: 20, width: 100, height: 50), transform: t)
        let box = TransformBox(box: Rect(minX: 14, minY: 14, maxX: 164, maxY: 39), degrees: 30)
        let expected = TransformRules.corners(of: box), corners = live.corners(of: d)
        #expect(corners.count == 4)
        for (c, e) in zip(corners, expected) {
            #expect(abs(c.x - e.x) < 1e-9 && abs(c.y - e.y) < 1e-9, "\(c) vs \(e)")
        }
    }
}
