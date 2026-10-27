// RasterizerTests.swift: FX-7's StageRasterizer (docs/blueprints/flare/features/flare-export.md). The PNG of
// `bounce` frame 0 is the scene's size at 1x and twice that at 2x; with the full-canvas Background left out, a
// transparent export leaves a corner at alpha 0 and an opaque one at alpha 255; the ball's center carries its
// fill; and the 1x frame is checked against Golden/flare/flare-raster-bounce-0-light.png within QB-V2's
// tolerance (recorded by the macOS job on its first run, as Golden/README.md says); a trimmed stroke paints only its
// kept part. macOS only.
#if canImport(CoreGraphics)
import CoreGraphics
import FlareCore
import FlareModel
import Foundation
import ImageIO
import SuiteModel
import SuiteUI
import Testing

@testable import FlareApp

@Suite struct RasterizerTests {
    /// `bounce` at frame 0 through FakeStage: Background, Shadow and Ball on a 550 × 400 scene.
    private static let bounce = FakeStage().drawList(FlareFixtures.bounce, sceneID: "scene-1", frame: 0, editing: nil)

    /// The pixel size ImageIO reads from `png`'s first image.
    private func pixelSize(_ png: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    /// The RGBA channels of pixel (x, y) in `image`, top row first.
    private func pixel(_ image: RGBAImage, x: Int, y: Int) -> [UInt8] {
        let at = (y * image.width + x) * 4
        guard at >= 0, at + 4 <= image.bytes.count else { return [] }
        return Array(image.bytes[at..<at + 4])
    }

    @Test func twoXIsTwiceThePixelSize() throws {
        let list = Self.bounce
        #expect(list.width == 550 && list.height == 400 && list.items.count == 3)
        let one = try StageRasterizer().png(list, scale: 1, transparent: false)
        let two = try StageRasterizer().png(list, scale: 2, transparent: false)
        #expect(one.starts(with: [0x89, 0x50, 0x4E, 0x47]), "a PNG signature")
        let oneSize = try #require(pixelSize(one))
        #expect(oneSize.width == 550 && oneSize.height == 400)
        let twoSize = try #require(pixelSize(two))
        #expect(twoSize.width == 1100 && twoSize.height == 800)
    }

    /// Without the full-canvas Background, the top-left corner shows the canvas: alpha 0 when transparent, the
    /// scene's background at alpha 255 otherwise. The ball (center 80, 100 at frame 0) carries its fill either way.
    @Test func transparentCornerHasAlphaZero() throws {
        var list = Self.bounce
        list.items.removeAll { $0.address.layerID == "background" }
        #expect(list.items.count == 2)
        let clear = try #require(RGBAImage(png: try StageRasterizer().png(list, scale: 1, transparent: true)))
        let opaque = try #require(RGBAImage(png: try StageRasterizer().png(list, scale: 1, transparent: false)))
        #expect(pixel(clear, x: 0, y: 0) == [0, 0, 0, 0])
        #expect(pixel(opaque, x: 0, y: 0) == [255, 255, 255, 255], "bounce's scene background is white")
        for image in [clear, opaque] {
            let ball = pixel(image, x: 80, y: 100)
            #expect(ball.count == 4)
            for (got, want) in zip(ball, [242, 92, 51, 255] as [Int]) {
                #expect(abs(Int(got) - want) <= 2, "ball center \(ball) should be its fill (0.95, 0.36, 0.2)")
            }
        }
    }

    @Test func zeroOrNonFiniteSizeThrows() {
        var list = Self.bounce
        list.width = 0
        #expect(throws: RasterizerError.self) { try StageRasterizer().png(list, scale: 1, transparent: false) }
        list.width = .infinity
        #expect(throws: RasterizerError.self) { try StageRasterizer().png(list, scale: 1, transparent: false) }
        #expect(throws: RasterizerError.self) {
            try StageRasterizer().png(Self.bounce, scale: .nan, transparent: false)
        }
    }

    /// QB-V4: the 1x PNG of bounce frame 0 against the rasterizer's golden within QB-V2's tolerance.
    @Test func bounceFrameZeroMatchesTheGolden() throws {
        let image = try #require(RGBAImage(png: try StageRasterizer().png(Self.bounce, scale: 1, transparent: false)))
        #expect(image.width == 550 && image.height == 400)
        assertGolden(image, name: "flare-raster-bounce-0", area: "flare", appearance: "light")
    }

    /// A stroke trimmed to the first half of a square's outline paints the top and right sides only, as the SVG
    /// export draws it: the PNG strokes the live stage's `strokePath`, not the whole outline.
    @Test func aTrimmedStrokePaintsOnlyItsHalf() throws {
        let square = FlarePath(polyline: [Point(x: 10, y: 10), Point(x: 90, y: 10), Point(x: 90, y: 90),
                                          Point(x: 10, y: 90)], closed: true)
        var stroke = Stroke(color: FlareColor(r: 1, g: 0, b: 0), width: 6)
        stroke.trim = StrokeTrim(start: 0, end: 0.5)
        let shape = FlareShape(points: [], fill: .solid(FlareColor(r: 0, g: 0, b: 0, a: 0)), path: square, stroke: stroke)
        let scene = FlareScene(id: "s", name: "S", width: 100, height: 100, layers: [Layer(id: "l", name: "L", shapes: [shape])])
        let list = LiveStage().drawList(Document(scenes: [scene]), sceneID: "s", frame: 0, editing: nil)
        let image = try #require(RGBAImage(png: try StageRasterizer().png(list, scale: 1, transparent: false)))
        #expect(pixel(image, x: 50, y: 10) == [255, 0, 0, 255], "top side, kept")
        #expect(pixel(image, x: 90, y: 50) == [255, 0, 0, 255], "right side, kept")
        #expect(pixel(image, x: 50, y: 90) == [255, 255, 255, 255], "bottom side, trimmed off")
        #expect(pixel(image, x: 10, y: 50) == [255, 255, 255, 255], "left side, trimmed off")
    }

    /// FV-7: a movie frame fills exactly the asked size, here MP4's even half of bounce (274 × 200, so x and y scale
    /// apart), in straight alpha: the ball (center 80, 100 at frame 0) lands at (40, 50) in its fill, and without the
    /// Background a transparent frame's corner is clear. A zero size throws instead of drawing.
    @Test func aMovieFrameFillsItsExactSizeInStraightAlpha() throws {
        var list = Self.bounce
        list.items.removeAll { $0.address.layerID == "background" }
        let frame = try StageRasterizer().frame(list, width: 274, height: 200, transparent: true)
        try #require(frame.width == 274 && frame.height == 200 && frame.rgba.count == 274 * 200 * 4)
        #expect(Array(frame.rgba[0..<4]) == [0, 0, 0, 0])
        let at = (50 * 274 + 40) * 4
        let ball = Array(frame.rgba[at..<at + 4])
        for (got, want) in zip(ball, [242, 92, 51, 255] as [Int]) {
            #expect(abs(Int(got) - want) <= 2, "ball center \(ball) should be its fill (0.95, 0.36, 0.2)")
        }
        #expect(throws: RasterizerError.self) { try StageRasterizer().frame(list, width: 0, height: 200, transparent: true) }
    }
}
#endif
