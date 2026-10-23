// WideGamutTests.swift: the colour pipeline (suite-imaging IM-15). A picture
// enters one working space wider than sRGB (extended-range linear sRGB,
// unclamped), every adjustment runs there, and only the display step or the
// output transform leaves it. The oracles are creative-core's own
// ProfileTransform and PixelBuffer conversions. Mutations:
// SuiteImaging.ImagingColor (`.keepsWideValues`, `.displayMatchesCore`,
// `.sixteenBits`).
import CoreColor
import CoreRaster
import CoreRender
import Testing
import SuiteImaging

struct WideGamutTests {
    /// A 1 x 1 opaque picture holding `c`, in the codecs' convention (the
    /// file's numbers decoded with the sRGB transfer curve).
    static func pixel(_ r: Float, _ g: Float, _ b: Float) throws -> PixelBuffer {
        try PixelBuffer(width: 1, height: 1, fill: RGBA(r: r, g: g, b: b, a: 1))
    }

    static func rgb(_ buffer: PixelBuffer) throws -> [Double] {
        let p = try buffer.pixel(x: 0, y: 0)
        return [Double(p.r), Double(p.g), Double(p.b)]
    }

    static func close(_ a: [Double], _ b: [Double], _ tolerance: Double) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) <= tolerance }
    }

    @Test func workingProfileIsLinearSRGB() {
        #expect(ImagingColor.workingProfile == ColorProfile.linearSRGB)
    }

    /// Display P3 red is outside sRGB: it enters as about (1.22, -0.04, -0.02),
    /// survives Exposure +0.5 and back, and leaves as P3 red at 16 bits.
    @Test func keepsWideValues() throws {
        let working = try ImagingColor.toWorking(try Self.pixel(1, 0, 0), from: .displayP3)
        let wide = try Self.rgb(working)
        #expect(Self.close(wide, [1.2249, -0.0421, -0.0196], 0.005), "\(wide)")
        #expect(wide[0] > 1 && wide[1] < 0 && wide[2] < 0)

        let edited = try working.exposure(stops: 0.5).exposure(stops: -0.5)
        #expect(Self.close(try Self.rgb(edited), wide, 1e-5))

        let out = try ImagingColor.toOutput(edited, profile: .displayP3, bitDepth: .sixteen)
        #expect(Self.close(out.fractions(x: 0, y: 0), [1, 0, 0, 1], 1.0 / 1000), "\(out.samples)")
    }

    /// A highlight above 1 is kept through the working space and cut only by
    /// the output's sample range.
    @Test func highlightStaysUntilOutput() throws {
        let working = try ImagingColor.toWorking(try Self.pixel(1.8, 0.5, 0.2), from: .sRGB)
        #expect(Self.close(try Self.rgb(working), [1.8, 0.5, 0.2], 1e-3))
        let darker = try working.exposure(stops: -1)
        #expect(Self.close(try Self.rgb(darker), [0.9, 0.25, 0.1], 1e-3))
        let out = try ImagingColor.toOutput(working, profile: .sRGB, bitDepth: .eight)
        #expect(out.samples.first == 255)
    }

    /// The P3 display step, CPU list and GPU program alike, is core's linear
    /// sRGB to Display P3 transform; an sRGB screen gets no step.
    @Test func displayMatchesCore() throws {
        #expect(ImagingColor.displaySteps(to: .sRGB).isEmpty)
        let steps = ImagingColor.displaySteps(to: .displayP3)
        #expect(steps.cpu.count == 1 && steps.gpu.count == 1)

        let transform = try ProfileTransform(from: .linearSRGB, to: .displayP3)
        let program = try ToneProgram(operations: steps.gpu)
        let cpu = CPUBackend()
        let colors: [[Float]] = [[1, 0, 0], [0, 1, 0], [0, 0, 1], [0.2, 0.5, 0.8], [0.9, 0.9, 0.1], [0.05, 0.6, 0.3]]
        for c in colors {
            let want = transform.applyLinear(Color3(Double(c[0]), Double(c[1]), Double(c[2])))
            var surface = try cpu.surface(try Self.pixel(c[0], c[1], c[2]))
            for step in steps.cpu { surface = try cpu.adjusted(surface, step) }
            let got = try Self.rgb(try cpu.read(surface))
            #expect(Self.close(got, [want.c0, want.c1, want.c2], 1.0 / 1000), "cpu \(c): \(got)")
            let g = program.map(RGBA(r: c[0], g: c[1], b: c[2], a: 1))
            #expect(Self.close([Double(g.r), Double(g.g), Double(g.b)], [want.c0, want.c1, want.c2], 1.0 / 1000), "gpu \(c)")
        }
    }

    /// A 16-bit output keeps the levels 8 bits can't: encoded 0.5 is 32768 of
    /// 65535, not 128 of 255.
    @Test func sixteenBits() throws {
        let half = Float(TransferCurve.decode(0.5))
        let working = try ImagingColor.toWorking(try Self.pixel(half, half, half), from: .sRGB)
        let deep = try ImagingColor.toOutput(working, profile: .sRGB, bitDepth: .sixteen)
        #expect(deep.bitDepth.maxSample == 65_535)
        #expect(deep.samples.prefix(3).allSatisfy { abs(Int($0) - 32_768) <= 1 }, "\(deep.samples)")
        #expect(deep.samples.last == 65_535)
        let byte = try ImagingColor.toOutput(working, profile: .sRGB, bitDepth: .eight)
        #expect(byte.samples == [128, 128, 128, 255])
    }

    /// Every 8-bit sRGB level comes back within one level.
    @Test func sRGBRoundTrips() throws {
        var bytes: [UInt8] = []
        for v in 0...255 { bytes += [UInt8(v), UInt8(255 - v), UInt8((v * 7) % 256), 255] }
        let file = try PixelBuffer(rgba8: bytes, width: 256, height: 1, colorSpace: .sRGB)
        let working = try ImagingColor.toWorking(file, from: .sRGB)
        let out = try ImagingColor.toOutput(working, profile: .sRGB, bitDepth: .eight)
        #expect(out.width == 256 && out.height == 1 && out.samples.count == bytes.count)
        let worst = zip(out.samples, bytes).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(worst <= 1)
    }

    /// Outside the picture there is no pixel.
    @Test func fractionsOutsideAreEmpty() throws {
        let out = try ImagingColor.toOutput(try Self.pixel(0, 0, 0), profile: .sRGB, bitDepth: .eight)
        #expect(out.fractions(x: 1, y: 0).isEmpty)
        #expect(out.fractions(x: 0, y: -1).isEmpty)
    }
}
