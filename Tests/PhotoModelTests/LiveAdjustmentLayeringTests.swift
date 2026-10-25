// LiveAdjustmentLayeringTests.swift: AL-1 of photo-adjustment-layers (PF-8
// part one). The live adjustment layer runs the whole-image adjustments'
// own path on the pixels below, bit for bit at opacity 1, normal blend and
// no mask; opacity 0 gives back `below`; opacity and a gray mask mix halfway
// within 1/255; Blur never applies on a layer. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct LiveAdjustmentLayeringTests {
    private let layering = LiveAdjustmentLayering()

    /// Every layer section changed from its default; Blur switched off, as on a layer.
    private func settings(blurSigma: Double = 0) -> AdjustmentSettings {
        var s = AdjustmentSettings()
        for edit: AdjustmentEdit in [
            .exposure(0.7), .blackPoint(0.05), .whitePoint(0.9), .gamma(1.3),
            .curvePoints([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.4, y: 0.55), CurvePoint(x: 1, y: 1)]),
            .hue(25), .saturation(30), .lightness(-10), .blurSigma(blurSigma),
        ] { s.apply(edit) }
        s.apply(.setEnabled(.blur, blurSigma > 0))
        return s
    }

    /// A 24 x 20 picture with a different color in every pixel.
    private func below() throws -> PixelBuffer {
        var buffer = try PixelBuffer(width: 24, height: 20)
        for y in 0..<20 {
            for x in 0..<24 {
                try buffer.setPixel(x: x, y: y, RGBA(r: Float(x) / 30, g: Float(y) / 25, b: 0.3, a: 1))
            }
        }
        return buffer
    }

    /// The largest difference in any component of two same-size buffers.
    private func largestDifference(_ a: PixelBuffer, _ b: PixelBuffer) throws -> Float {
        var largest: Float = 0
        for y in 0..<a.height {
            for x in 0..<a.width {
                let p = try a.pixel(x: x, y: y), q = try b.pixel(x: x, y: y)
                largest = max(largest, abs(p.r - q.r), abs(p.g - q.g), abs(p.b - q.b), abs(p.a - q.a))
            }
        }
        return largest
    }

    @Test func isBuiltWithTheFourLayerKinds() {
        #expect(layering.unavailableHelp == nil)
        #expect(layering.kinds == [.exposure, .levels, .curves, .hueSaturation])
        #expect(LiveAdjustmentLayers.make().unavailableHelp == nil)
    }

    @Test func fullOpacityNormalNoMaskEqualsTheWholeImagePathBitForBit() throws {
        let below = try below(), s = settings()
        let out = try layering.applying(s, to: below, opacity: 1, blendMode: .normal, mask: nil)
        #expect(out == (try s.applied(to: below)))
        #expect(out != below)
    }

    @Test func opacityZeroGivesBackBelowBitForBit() throws {
        let below = try below()
        #expect(try layering.applying(settings(), to: below, opacity: 0, blendMode: .normal, mask: nil) == below)
        #expect(try layering.applying(settings(), to: below, opacity: 0, blendMode: .screen, mask: nil) == below)
    }

    @Test func halfOpacityLiesHalfway() throws {
        let below = try below(), s = settings()
        let full = try s.applied(to: below)
        let half = try layering.applying(s, to: below, opacity: 0.5, blendMode: .normal, mask: nil)
        var expected = below
        for y in 0..<below.height {
            for x in 0..<below.width {
                let p = try below.pixel(x: x, y: y), q = try full.pixel(x: x, y: y)
                try expected.setPixel(
                    x: x, y: y, RGBA(r: (p.r + q.r) / 2, g: (p.g + q.g) / 2, b: (p.b + q.b) / 2, a: (p.a + q.a) / 2))
            }
        }
        #expect(try largestDifference(half, expected) <= 1 / 255)
        #expect(try largestDifference(half, below) > 1 / 255)
    }

    @Test func aHalfGrayMaskEqualsHalfOpacity() throws {
        let below = try below(), s = settings()
        let gray = try PixelBuffer(width: below.width, height: below.height, fill: RGBA(r: 0.5, g: 0.5, b: 0.5, a: 1))
        let masked = try layering.applying(s, to: below, opacity: 1, blendMode: .normal, mask: gray)
        let half = try layering.applying(s, to: below, opacity: 0.5, blendMode: .normal, mask: nil)
        #expect(try largestDifference(masked, half) <= 1 / 255)
        let white = try PixelBuffer(width: below.width, height: below.height, fill: RGBA(r: 1, g: 1, b: 1, a: 1))
        #expect(try layering.applying(s, to: below, opacity: 1, blendMode: .normal, mask: white)
            == (try s.applied(to: below)))
        let black = try PixelBuffer(width: below.width, height: below.height, fill: RGBA(r: 0, g: 0, b: 0, a: 1))
        #expect(try largestDifference(
            layering.applying(s, to: below, opacity: 1, blendMode: .normal, mask: black), below) <= 1e-6)
    }

    @Test func aMaskOfAnotherSizeIsRefused() throws {
        let below = try below(), small = try PixelBuffer(width: 3, height: 3, fill: RGBA(r: 1, g: 1, b: 1, a: 1))
        #expect(throws: RasterError.self) {
            try layering.applying(settings(), to: below, opacity: 1, blendMode: .normal, mask: small)
        }
    }

    @Test func blurEnabledInTheSettingsIsIgnored() throws {
        let below = try below(), blurred = settings(blurSigma: 3)
        #expect(blurred.isEnabled(.blur))
        #expect(try blurred.applied(to: below) != (try settings().applied(to: below)))
        let out = try layering.applying(blurred, to: below, opacity: 1, blendMode: .normal, mask: nil)
        #expect(out == (try settings().applied(to: below)))
        let half = try layering.applying(blurred, to: below, opacity: 0.5, blendMode: .multiply, mask: nil)
        #expect(half == (try layering.applying(settings(), to: below, opacity: 0.5, blendMode: .multiply, mask: nil)))
    }
}
