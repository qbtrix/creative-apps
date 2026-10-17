// RasterizerTests.swift: FX-7's StageRasterizer (docs/blueprints/flare/features/flare-export.md). The PNG of
// `bounce` frame 0 is the scene's size at 1x and twice that at 2x; with the full-canvas Background left out, a
// transparent export leaves a corner at alpha 0 and an opaque one at alpha 255; the ball's center carries its
// fill; and the 1x frame is checked against Golden/flare/flare-raster-bounce-0-light.png within QB-V2's
// tolerance (recorded by the macOS job on its first run, as Golden/README.md says). macOS only.
#if canImport(CoreGraphics)
import CoreGraphics
import FlareCore
import FlareModel
import Foundation
import ImageIO
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
}
#endif
