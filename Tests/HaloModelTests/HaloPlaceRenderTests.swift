// HaloPlaceRenderTests.swift: placed-images PH-2, the renderer's checks,
// written first and off until PH-5 draws a solid's picture. RJ-H36's four
// pixels (a red left half, a blue right half, the background around it), a
// 2× scale doubles the picture's footprint, a picture never draws outside
// its solid's outline at a 30° turn, an SVG ring keeps its hole, an asset
// decodes once for two solids, and a full-frame 1080p picture's cost is
// reported. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import FlareCore
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloPlaceRenderTests {
    /// RJ-H36's logo: a 200 × 100 PNG, #FF0000 left of x = 100, #0000FF right of it.
    static let logoBase64 = """
        iVBORw0KGgoAAAANSUhEUgAAAMgAAABkCAYAAADDhn8LAAABRElEQVR42u3TsQkAAAzDsPz/dHpFIYMGP2BQmlQ7WTCWA4AIEEAE\
        CCACBBABAogAESCACBBABAggAgQQASJAABEggAgQQAQIIAJEgAAiQAARIIAIEEAECCAuACJAABEggAgQQAQIIAJEgAAiQAARIIAI\
        EEAEiAABRIAAIkAAESCACBBZAIgAAUSAACJAABEggAgQAQKIAAFEgAAiQAARIAIEEAECiAABRIAAIkAECCACBBABAogAAUSAAGID\
        IAIEEAECiAABRIAAIkAECCACBBABAogAAUSACBBABAggAgQQAQKIABEggAgQQAQIIAIEEAECiAARIIAIEEAECCACBBABIkAAESCA\
        CBBABAggAkSAACJAABEggAgQQASIHABEgAAiQAARIIAIEEAEiAABRIAAIkAAESCACBABAogAAUSAAKLPDlYGrNa0kF6LAAAAAElF\
        TkSuQmCC
        """
    /// A 64 × 64 blue square with a 32 × 32 hole, even-odd.
    static let ring = """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><path fill="#0000FF" fill-rule="evenodd" \
        d="M0 0 H64 V64 H0 Z M16 16 H48 V48 H16 Z"/></svg>
        """
    static let logo = PlacedAsset(
        id: "logo", name: "logo.png", format: .png, natural: Size(width: 200, height: 100),
        data: Data(base64Encoded: logoBase64) ?? Data())

    /// A 2/255 tolerance on each channel.
    static let tolerance: Float = 2.0 / 255

    static let black = HaloDrawItem(
        layerID: "bg", kind: .solid, bounds: HaloLayerRect(x: 0, y: 0, width: 400, height: 400), matrix: .identity,
        opacity: 1, color: HaloLayerColor(red: 0, green: 0, blue: 0), blendMode: .normal)

    /// A solid showing `asset` over `bounds`, its picture in the same box.
    static func placed(
        _ asset: PlacedAsset = logo, id: String = "p", bounds: HaloLayerRect = HaloLayerRect(x: 100, y: 150, width: 200, height: 100),
        matrix: HaloMatrix = .identity
    ) -> HaloDrawItem {
        let box = Rect(minX: bounds.x, minY: bounds.y, maxX: bounds.x + bounds.width, maxY: bounds.y + bounds.height)
        return HaloDrawItem(
            layerID: id, kind: .solid, bounds: bounds, matrix: matrix, opacity: 1,
            color: HaloLayerColor(red: 0, green: 1, blue: 0), blendMode: .normal,
            placedAsset: asset, placedImage: PlacedImage(assetID: asset.id, box: box))
    }

    static func render(_ items: [HaloDrawItem], width: Int = 400, height: Int = 400) throws -> PixelBuffer {
        try LiveFrameRendering().render(
            HaloDrawList(width: width, height: height, frame: 0, items: items), width: width, height: height, text: nil
        ).pixels
    }

    static func isRed(_ p: RGBA) -> Bool { p.r >= 1 - tolerance && p.g <= tolerance && p.b <= tolerance && p.a >= 1 - tolerance }
    static func isBlue(_ p: RGBA) -> Bool { p.r <= tolerance && p.g <= tolerance && p.b >= 1 - tolerance && p.a >= 1 - tolerance }
    static func isBlack(_ p: RGBA) -> Bool { p.r <= tolerance && p.g <= tolerance && p.b <= tolerance && p.a >= 1 - tolerance }

    /// `m` about the 400 × 400 frame's centre.
    static func about(_ m: HaloMatrix) -> HaloMatrix {
        .translation(x: 200, y: 200) * m * .translation(x: -200, y: -200)
    }

    @Test(.disabled("waits on PH-5")) func logoPixels() throws {
        let pixels = try Self.render([Self.black, Self.placed()])
        #expect(Self.isRed(try pixels.pixel(x: 110, y: 200)))
        #expect(Self.isBlue(try pixels.pixel(x: 290, y: 200)))
        #expect(Self.isBlack(try pixels.pixel(x: 98, y: 200)))
        #expect(Self.isBlack(try pixels.pixel(x: 200, y: 148)))
    }

    @Test(.disabled("waits on PH-5")) func scaleKeyScalesPicture() throws {
        let pixels = try Self.render([Self.black, Self.placed(matrix: Self.about(.scale(x: 2, y: 2)))])
        #expect(Self.isRed(try pixels.pixel(x: 5, y: 200)))
        #expect(Self.isBlue(try pixels.pixel(x: 395, y: 200)))
        #expect(Self.isRed(try pixels.pixel(x: 150, y: 105)))
        #expect(Self.isBlack(try pixels.pixel(x: 200, y: 95)))
    }

    @Test(.disabled("waits on PH-5")) func staysInsideOutline() throws {
        // The picture's box is twice the solid's, so only the outline can stop it.
        var item = Self.placed(matrix: Self.about(.rotation(degrees: 30)))
        item.placedImage = PlacedImage(assetID: "logo", box: Rect(minX: 0, minY: 100, maxX: 400, maxY: 300))
        let pixels = try Self.render([item])
        let back = Self.about(.rotation(degrees: -30))
        var inside = 0
        for y in stride(from: 0, to: 400, by: 4) {
            for x in stride(from: 0, to: 400, by: 4) {
                let p = back.apply(Point(x: Double(x) + 0.5, y: Double(y) + 0.5))
                let a = try pixels.pixel(x: x, y: y).a
                if p.x > 98.5, p.x < 301.5, p.y > 148.5, p.y < 251.5 { inside += a >= 1 - Self.tolerance ? 1 : 0; continue }
                #expect(a <= Self.tolerance, "drawn outside the outline at (\(x), \(y))")
            }
        }
        #expect(inside > 1000)
    }

    @Test(.disabled("waits on PH-5")) func svgRingKeepsHole() throws {
        let ring = PlacedAsset(id: "ring", name: "ring.svg", format: .svg, natural: Size(width: 64, height: 64), data: Data(Self.ring.utf8))
        let pixels = try Self.render([Self.placed(ring, bounds: HaloLayerRect(x: 0, y: 0, width: 64, height: 64))], width: 64, height: 64)
        #expect(Self.isBlue(try pixels.pixel(x: 8, y: 8)))
        #expect(try pixels.pixel(x: 32, y: 32).a <= Self.tolerance)
    }

    @Test(.disabled("waits on PH-5")) func decodesOncePerAsset() throws {
        // Core decodes PNG on Linux but not JPEG, so two solids share the PNG logo.
        var drawing = HaloPlacedDrawing()
        for item in [Self.placed(id: "a"), Self.placed(id: "b", bounds: HaloLayerRect(x: 0, y: 0, width: 200, height: 100))] {
            let (asset, image) = (try #require(item.placedAsset), try #require(item.placedImage))
            #expect(try drawing.source(asset, image, matrix: item.matrix, width: 400, height: 400) != nil)
        }
        #expect(drawing.decodes == 1)
    }

    @Test(.disabled("waits on PH-5")) func fullFrameCost() throws {
        let photo = try PNGCodec().encodePNG(
            try PixelBuffer(width: 1920, height: 1080, fill: RGBA(r: 0.2, g: 0.4, b: 0.6, a: 1)), bitsPerChannel: 8)
        let asset = PlacedAsset(id: "photo", name: "photo.png", format: .png, natural: Size(width: 1920, height: 1080), data: photo)
        let bounds = HaloLayerRect(x: 0, y: 0, width: 1920, height: 1080)
        let item = Self.placed(asset, bounds: bounds)
        var plain = item
        plain.placedAsset = nil; plain.placedImage = nil
        _ = try Self.render([item], width: 1920, height: 1080)  // the first decode
        let clock = ContinuousClock()
        let base = try clock.measure { _ = try Self.render([plain], width: 1920, height: 1080) }
        let picture = try clock.measure { _ = try Self.render([item], width: 1920, height: 1080) }
        let added = picture - base
        let ms = Double(added.components.seconds) * 1000 + Double(added.components.attoseconds) / 1e15
        print("HALO-PLACED-FRAME added \(ms) ms")
    }
}
