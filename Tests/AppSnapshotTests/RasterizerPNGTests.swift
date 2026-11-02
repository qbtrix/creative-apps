// RasterizerPNGTests.swift (shared-codecs SC-9; packet docs/blueprints/suiteui/features/shared-codecs.md,
// MJ-SC-raster): once SC-10 moves DesignRasterizer and StageRasterizer onto `SuiteImageIO.png`, their PNGs
// must still hold the pixels they hold today. Each PNG is checked with core's `PNG.info` (the planned size,
// 8 bits, not interlaced), decoded with core's `PNG.read`, and held to what the existing rasterizer tests read
// through ImageIO: every pixel within 2 levels of the ImageIO decode (both premultiplied 8-bit sRGB) and the
// known pixels of DesignRasterizerTests and RasterizerTests (the gray shape and its transparent corners; the
// white scene, the clear corner and the ball's fill). Written first, disabled until SC-10. macOS only.
#if canImport(AppKit)
import CoreRaster
import FlareModel
import Foundation
import SuiteUI
import Testing

@testable import DesignApp
@testable import DesignModel
@testable import FlareApp

@MainActor
@Suite struct RasterizerPNGTests {
    /// `png` decoded by core's `PNG.read` as premultiplied 8-bit sRGB RGBA, top row first: the form
    /// `RGBAImage(png:)` reads through ImageIO, so the two compare byte for byte.
    private func coreDecode(_ png: Data) throws -> RGBAImage {
        let buffer = try PNG.read(png)
        let straight = try buffer.rgba8()
        var bytes = straight
        var at = 0
        while at + 4 <= bytes.count {
            let alpha = Int(straight[at + 3])
            for channel in 0..<3 {
                bytes[at + channel] = UInt8((Int(straight[at + channel]) * alpha + 127) / 255)
            }
            at += 4
        }
        return RGBAImage(width: buffer.width, height: buffer.height, bytes: bytes)
    }

    /// The RGBA channels of pixel (x, y), top row first; empty outside the image.
    private func pixel(_ image: RGBAImage, x: Int, y: Int) -> [Int] {
        let at = (y * image.width + x) * 4
        guard x >= 0, y >= 0, x < image.width, at + 4 <= image.bytes.count else { return [] }
        return image.bytes[at..<at + 4].map(Int.init)
    }

    private func near(_ got: [Int], _ want: [Int], within: Int = 2) -> Bool {
        got.count == want.count && zip(got, want).allSatisfy { abs($0 - $1) <= within }
    }

    /// `png` is an 8-bit, non-interlaced `width` × `height` PNG, and core's decode of it matches ImageIO's within
    /// 2 levels at every pixel. Returns core's decode for the known-pixel checks.
    private func decodesAlike(_ png: Data, width: Int, height: Int, _ name: String) throws -> RGBAImage {
        let info = try PNG.info(png)
        #expect(info.width == width && info.height == height, "\(name): \(info)")
        #expect(info.bitDepth == 8 && !info.interlaced, "\(name): \(info)")
        #expect([2, 6].contains(info.colorType), "\(name): colour type \(info.colorType)")
        let core = try coreDecode(png)
        let imageIO = try #require(RGBAImage(png: png), "\(name): ImageIO can't read it")
        try #require(core.width == imageIO.width && core.height == imageIO.height && core.bytes.count == imageIO.bytes.count)
        var differing = 0
        var first = ""
        for (index, (a, b)) in zip(core.bytes, imageIO.bytes).enumerated() where abs(Int(a) - Int(b)) > 2 {
            if differing == 0 { first = "pixel \(index / 4) channel \(index % 4): core \(a), ImageIO \(b)" }
            differing += 1
        }
        #expect(differing == 0, "\(name): \(differing) channels differ by more than 2, first \(first)")
        return core
    }

    /// Design: the one-shape 200 × 100 page keeps its clear corners and gray shape, and `cards`' Desktop frame
    /// at 1x decodes the same through core and ImageIO.
    @Test(.disabled("waits on SC-10")) func designPNGDecodesToTheSamePixels() throws {
        let shape = DesignNode(id: "r", name: "R", kind: .rectangle, frame: DesignRect(x: 50, y: 25, width: 100, height: 50))
        let page = DesignPage(id: "p", name: "P", frameWidth: 200, frameHeight: 100, nodes: [shape])
        let item = DesignExportItem(nodeID: "p", fileName: "P.png", width: 200, height: 100, pixelWidth: 200, pixelHeight: 100)
        let image = try decodesAlike(try DesignRasterizer.png(try page.raster(item)), width: 200, height: 100, "one shape")
        for (x, y) in [(0, 0), (199, 0), (0, 99), (199, 99), (20, 50)] {
            #expect(pixel(image, x: x, y: y).last == 0, "(\(x), \(y)) is \(pixel(image, x: x, y: y))")
        }
        #expect(near(pixel(image, x: 100, y: 50), [217, 217, 217, 255]), "the shape: \(pixel(image, x: 100, y: 50))")

        let cards = DesignFixtures.cards
        let desktop = try #require(try cards.exportPlan(DesignExportOptions(format: .png, scale: 1, scope: .frame), existing: []).first)
        _ = try decodesAlike(try DesignRasterizer.png(try cards.exportRaster(desktop)), width: 1440, height: 1024, "Desktop")
    }

    /// Flare: `bounce` frame 0 without its Background, opaque and transparent, keeps its white or clear corner
    /// and the ball's fill (0.95, 0.36, 0.2), and the whole frame decodes the same through core and ImageIO.
    @Test(.disabled("waits on SC-10")) func flarePNGDecodesToTheSamePixels() throws {
        var list = FakeStage().drawList(FlareFixtures.bounce, sceneID: "scene-1", frame: 0, editing: nil)
        _ = try decodesAlike(try StageRasterizer().png(list, scale: 1, transparent: false), width: 550, height: 400, "bounce")
        list.items.removeAll { $0.address.layerID == "background" }
        for (transparent, corner) in [(true, [0, 0, 0, 0]), (false, [255, 255, 255, 255])] {
            let png = try StageRasterizer().png(list, scale: 1, transparent: transparent)
            let image = try decodesAlike(png, width: 550, height: 400, "bounce, transparent \(transparent)")
            #expect(pixel(image, x: 0, y: 0) == corner, "transparent \(transparent): corner \(pixel(image, x: 0, y: 0))")
            #expect(near(pixel(image, x: 80, y: 100), [242, 92, 51, 255]), "ball center \(pixel(image, x: 80, y: 100))")
        }
    }
}
#endif
