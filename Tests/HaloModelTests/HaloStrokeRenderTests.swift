// HaloStrokeRenderTests.swift: stroke-style HK-5, the renderer's checks,
// written first. An 8 pt stroke covers the band around a shape's outline and
// not its centre, which keeps the fill; Trim End keyed 0 to 1 over 24 frames
// draws nothing at frame 0, the first half of the outline at 12 and all of it
// at 24; a dash pattern leaves gaps. Linux and macOS.
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

@Suite struct HaloStrokeRenderTests {
    /// Blue, 8 pt.
    static let blue = VectorStroke(color: FlareCore.Color(r: 0, g: 0, b: 1), width: 8)

    /// A 220 × 220 composition holding one red circle (the default ellipse)
    /// of radius 100 centred at (110, 110), stroked with `stroke`.
    static func comp(_ stroke: VectorStroke?, tracks: [String: [HaloKeyframe]] = [:]) -> HaloComposition {
        var layer = HaloLayer(
            id: "c", name: "Circle", kind: .shape, inFrame: 0, outFrame: 48,
            color: HaloLayerColor(red: 1, green: 0, blue: 0), rect: HaloLayerRect(x: 10, y: 10, width: 200, height: 200))
        layer.stroke = stroke
        layer.tracks = tracks
        return HaloComposition(
            id: "comp-1", name: "Comp", width: 220, height: 220, framesPerSecond: 24, durationFrames: 48, layers: [layer])
    }

    static func render(_ c: HaloComposition, at frame: Int = 0) throws -> PixelBuffer {
        try #require(
            c.renderFrame(at: frame, scale: 1, drawing: LiveFrameDrawing(), rendering: LiveFrameRendering(), text: nil)
        ).pixels
    }

    /// The pixel on the circle's outline at `degrees` (0 is the right, 90 the
    /// bottom: the outline runs right, bottom, left, top).
    static func onOutline(_ pixels: PixelBuffer, _ degrees: Double) throws -> RGBA {
        let t = degrees * .pi / 180
        return try pixels.pixel(x: Int((110 + 100 * cos(t)).rounded(.down)), y: Int((110 + 100 * sin(t)).rounded(.down)))
    }

    static func isBlue(_ p: RGBA) -> Bool { p.b > 0.9 && p.r < 0.1 }
    static func isRed(_ p: RGBA) -> Bool { p.r > 0.9 && p.b < 0.1 }

    @Test func strokeCoversTheBandNotTheCentre() throws {
        let pixels = try Self.render(Self.comp(Self.blue))
        for degrees in stride(from: 0.0, to: 360, by: 5) {
            #expect(Self.isBlue(try Self.onOutline(pixels, degrees)), "no stroke at \(degrees)°")
        }
        #expect(Self.isBlue(try pixels.pixel(x: 7, y: 110)), "the band's outer half is missing")
        #expect(Self.isRed(try pixels.pixel(x: 110, y: 110)), "the centre isn't the fill")
        #expect(Self.isRed(try pixels.pixel(x: 20, y: 110)), "the band is wider than 8 pt")
        #expect(try pixels.pixel(x: 0, y: 0).a == 0)
    }

    @Test func noStrokeDrawsOnlyTheFill() throws {
        let pixels = try Self.render(Self.comp(nil))
        #expect(!Self.isBlue(try Self.onOutline(pixels, 180)))
        #expect(try pixels.pixel(x: 7, y: 110).a == 0)
    }

    @Test func trimEndKeyedOverTwentyFourFramesDrawsOn() throws {
        let c = Self.comp(Self.blue, tracks: ["trimEnd": [HaloKeyframe(frame: 0, value: 0), HaloKeyframe(frame: 24, value: 1)]])
        let start = try Self.render(c, at: 0), half = try Self.render(c, at: 12), whole = try Self.render(c, at: 24)
        #expect(!Self.isBlue(try Self.onOutline(start, 90)), "frame 0 draws a stroke")
        #expect(Self.isBlue(try Self.onOutline(half, 45)) && Self.isBlue(try Self.onOutline(half, 90)))
        #expect(Self.isBlue(try Self.onOutline(half, 135)), "frame 12 misses the first half")
        #expect(!Self.isBlue(try Self.onOutline(half, 225)) && !Self.isBlue(try Self.onOutline(half, 270)))
        #expect(!Self.isBlue(try Self.onOutline(half, 315)), "frame 12 draws the second half")
        #expect(Self.isBlue(try Self.onOutline(whole, 270)), "frame 24 misses the top")
    }

    @Test func dashesLeaveGaps() throws {
        var dashed = Self.blue
        dashed.dash = [20, 20]
        let pixels = try Self.render(Self.comp(dashed))
        let stroked = try stride(from: 0.0, to: 360, by: 2).map { Self.isBlue(try Self.onOutline(pixels, $0)) }
        #expect(stroked.contains(true), "no dash drawn")
        #expect(stroked.contains(false), "no gap between dashes")
    }
}
