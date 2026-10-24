// SuiteImageIOTests.swift (shared-codecs SC-1, turned on by SC-4; packet docs/blueprints/suiteui/features/shared-codecs.md):
// the macOS facts `SuiteImageIO` (Sources/SuiteShell/SuiteImageIO.swift) must get right: an Exif-orientation-6
// JPEG decodes upright, a Display P3 PNG reaches sRGB output without a colour shift, a HEIC round-trips, and a
// 24 MP JPEG decodes at `longestSide: 512` near today's time (report-only). The JPEG is RJ-X46's fixture,
// Tests/RealJobs/photo/rotated-photo/input/rotated-6.jpg. macOS only.
#if canImport(AppKit)
import CoreGraphics
import CoreRaster
import Foundation
import SuiteModel
import SuiteShell
import Testing

/// Images the SuiteImageIO suites make for themselves.
enum ImageIOFixtures {
    enum Missing: Error { case unavailable(String) }

    /// Straight 8-bit sRGB bytes as a buffer: red rising left to right, green top to bottom, blue flat. Smooth,
    /// so lossy formats stay close.
    static func gradient(width: Int, height: Int) throws -> PixelBuffer {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                bytes[i] = UInt8(60 + 120 * x / max(width - 1, 1))
                bytes[i + 1] = UInt8(80 + 100 * y / max(height - 1, 1))
                bytes[i + 2] = 140
            }
        }
        return try PixelBuffer(rgba8: bytes, width: width, height: height)
    }

    /// A `width` x `height` 8-bit context in `space` (sRGB by default) filled with `components`.
    static func filled(_ components: [CGFloat], width: Int = 16, height: Int = 8,
                       space name: CFString = CGColorSpace.sRGB) throws -> CGImage {
        guard let space = CGColorSpace(name: name),
            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let color = CGColor(colorSpace: space, components: components)
        else { throw Missing.unavailable("an 8-bit context") }
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw Missing.unavailable("an 8-bit image") }
        return image
    }

    /// A 4 x 4 PNG tagged Display P3, every pixel P3's pure red.
    static func p3RedPNG() throws -> Data {
        try SuiteImageIO.encode(try filled([1, 0, 0, 1], width: 4, height: 4, space: CGColorSpace.displayP3),
                                as: SuiteImageFormat.png, quality: nil)
    }
}

@Suite struct SuiteImageIOTests {
    static func rotatedJPEG() throws -> URL {
        try packageRoot().appending(path: "Tests/RealJobs/photo/rotated-photo/input/rotated-6.jpg")
    }

    /// The straight 8-bit sRGB R, G, B of `buffer`'s pixel at (x, y).
    static func rgb(_ buffer: PixelBuffer, _ x: Int, _ y: Int) throws -> [Int] {
        let one = try buffer.cropped(x: x, y: y, width: 1, height: 1).rgba8()
        return one.prefix(3).map(Int.init)
    }

    /// A 4032 x 3024 JPEG stored with Exif orientation 6 decodes 3024 x 4032, its top-left pixel the stored
    /// bottom-left one, and `info` reports the shown size.
    @Test func exifOrientation6DecodesUpright() throws {
        let url = try Self.rotatedJPEG()
        let data = try Data(contentsOf: url)
        let info = try SuiteImageIO.info(url)
        #expect(info.orientation == 6)
        #expect(info.width == 3024 && info.height == 4032, "info's size is the shown one: \(info.width) x \(info.height)")
        let stored = try JPEG.read(data)
        #expect(stored.width == 4032 && stored.height == 3024, "the file stores the frame sideways")
        let upright = try SuiteImageIO.decode(data, longestSide: nil)
        #expect(upright.width == 3024 && upright.height == 4032)
        #expect(try Self.rgb(upright, 0, 0) == Self.rgb(stored, 0, stored.height - 1),
                "the top-left pixel is the stored bottom-left one")
        let sky = try Self.rgb(upright, 1500, 600)
        #expect(zip(sky, [90, 150, 220]).allSatisfy { abs($0 - $1) <= 2 }, "the sky band runs across the top: \(sky)")
    }

    /// A Display P3 PNG's pure P3 red decodes into the working space outside sRGB, and encoding it as an sRGB
    /// PNG gives the red sRGB clips it to, within 1/255.
    @Test func displayP3PNGConvertsToSRGB() throws {
        let png = try ImageIOFixtures.p3RedPNG()
        let working = try SuiteImageIO.decode(png, longestSide: nil)
        let red = try working.pixel(x: 1, y: 1)
        #expect(red.r > 1.1 && red.g < -0.02, "P3 red is wider than sRGB: \(red)")
        let srgb = try PNG.read(SuiteImageIO.encode(working, as: .png))
        let out = try Self.rgb(srgb, 1, 1)
        #expect(zip(out, [255, 0, 0]).allSatisfy { abs($0 - $1) <= 1 }, "sRGB's clip of P3 red: \(out)")
    }

    /// A buffer encoded as HEIC at quality 0.9 decodes to the same size and within 3/255 of every pixel.
    @Test func heicRoundTrips() throws {
        let source = try ImageIOFixtures.gradient(width: 64, height: 48)
        let heic = try SuiteImageIO.encode(source, as: .heic(quality: 0.9))
        #expect(heic.count > 12 && String(decoding: heic[4..<8], as: UTF8.self) == "ftyp", "an ISO media file")
        let back = try SuiteImageIO.decode(heic, longestSide: nil)
        #expect(back.width == 64 && back.height == 48)
        let a = try source.rgba8(), b = try back.rgba8()
        let worst = zip(a, b).map { abs(Int($0) - Int($1)) }.max() ?? 255
        #expect(a.count == b.count && worst <= 3, "every sample within 3 levels, worst \(worst)")
    }

    /// A 24 MP JPEG at `longestSide: 512` decodes within 10% of the time today's ImageIO thumbnail takes
    /// (`SuiteImageIO.uprightImage`, the call Library's decoder makes). Report-only, the packet's "no slower" row:
    /// it records the two times and fails only when the decode fails.
    @Test func thumbnailDecodeTime() throws {
        // Made by ImageIO's writer, so only the decodes under test run through creative-core.
        let source = try ImageIOFixtures.filled([0.35, 0.6, 0.85, 1], width: 6000, height: 4000)
        let jpeg = try SuiteImageIO.encode(source, as: SuiteImageFormat.jpeg, quality: 0.9)
        let clock = ContinuousClock()
        var thumbnail: PixelBuffer?
        let ours = try clock.measure { thumbnail = try SuiteImageIO.decode(jpeg, longestSide: 512) }
        let today = try clock.measure { _ = try SuiteImageIO.uprightImage(jpeg, longestSide: 512) }
        #expect(thumbnail.map { max($0.width, $0.height) } == 512)
        let ratio = ours / today
        print("SuiteImageIOTests.thumbnailDecodeTime: decode \(ours), ImageIO thumbnail \(today), ratio \(ratio)"
              + (ratio <= 1.1 ? "" : " (over the 10% budget, report-only)"))
    }
}
#endif
