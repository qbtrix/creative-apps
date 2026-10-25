// SuiteImageIOFormatsTests.swift (shared-codecs SC-4; packet docs/blueprints/suiteui/features/shared-codecs.md, the
// SC-4 Checks row and "no dead formats"): every format `SuiteImageIO.readable` names decodes a fixture, every one
// `writable` names round-trips, a 16-bit TIFF keeps a 1/1000 step that 8 bits loses, an OpenEXR value above 1
// survives decode, a Display P3 PNG's red decodes outside sRGB, and a 16-bit TIFF written in Display P3 reads
// back within 1/1000. Fixtures are made here through ImageIO's own writer where it writes the type; WebP, which
// ImageIO only reads, is Fixtures/formats/tiny.webp, and HEIF is RJ-X46's HEIC (same container). Camera RAW is
// shared-raw's to prove (its DNG fixtures). macOS only.
#if canImport(AppKit)
import CoreColor
import CoreGraphics
import CoreRaster
import Foundation
import SuiteModel
import SuiteShell
import Testing

@Suite struct SuiteImageIOFormatsTests {
    typealias Fixture = ImageIOFixtures.Missing

    /// `pixels` (R, G, B, A in extended linear sRGB, straight, opaque) as a 32-bit float image.
    static func floatImage(_ pixels: [Float], width: Int, height: Int) throws -> CGImage {
        let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        let data = pixels.withUnsafeBufferPointer { Data(buffer: $0) }
        guard let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB),
            let provider = CGDataProvider(data: data as CFData),
            let image = CGImage(width: width, height: height, bitsPerComponent: 32, bitsPerPixel: 128,
                                bytesPerRow: width * 16, space: space, bitmapInfo: CGBitmapInfo(rawValue: info),
                                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { throw Fixture.unavailable("a float image") }
        return image
    }

    /// The fixture bytes for `format` and the longest side to decode at; nil when there is none on this Mac.
    static func fixture(_ format: SuiteImageFormat) throws -> (Data, Int?)? {
        let root = try packageRoot()
        switch format {
        case .webp: return (try Data(contentsOf: root.appending(path: "Tests/AppSnapshotTests/Fixtures/formats/tiny.webp")), nil)
        case .heif: return (try Data(contentsOf: root.appending(path: "Tests/RealJobs/photo/rotated-photo/input/rotated-6.heic")), 64)
        default:
            let image = try ImageIOFixtures.filled([0.8, 0.25, 0.15, 1])
            return (try? SuiteImageIO.encode(image, as: format, quality: 0.95)).map { ($0, nil) }
        }
    }

    @Test func eachReadableFormatsFixtureDecodes() throws {
        let readable = SuiteImageIO.readable
        #expect(readable.isSuperset(of: [.png, .jpeg, .heic, .tiff]), "this Mac reads the formats Photo writes")
        #expect(readable.isSubset(of: Set(SuiteImageFormats.all)))
        for format in readable.sorted(by: { $0.rawValue < $1.rawValue }) where format != .cameraRaw {
            guard let fixture = try Self.fixture(format) else {
                Issue.record("no \(format.title) fixture: ImageIO reads it but doesn't write it, and none is committed")
                continue
            }
            let (data, side) = fixture
            let decoded = try SuiteImageIO.decode(data, longestSide: side)
            #expect(decoded.width > 0 && decoded.height > 0, "\(format.title) decodes")
            if let side { #expect(max(decoded.width, decoded.height) == side, "\(format.title) shrinks while decoding") }
        }
    }

    @Test func eachWritableFormatRoundTrips() throws {
        let writable = SuiteImageIO.writable
        #expect(writable == Set(SuiteImageFormats.writable), "this Mac writes every format the registry writes")
        let source = try ImageIOFixtures.gradient(width: 48, height: 32)
        let expected = try source.rgba8()
        // Each writable format as the adapter's Format, and how many levels its round trip may move a sample.
        let written: [SuiteImageFormat: (SuiteImageIO.Format, Int)] = [
            .png: (.png, 1), .jpeg: (.jpeg(quality: 0.95), 4), .heic: (.heic(quality: 0.95), 4), .tiff: (.tiff(bitDepth: 8), 1),
        ]
        for format in writable.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let pair = written[format] else {
                Issue.record("\(format.title) is writable but has no SuiteImageIO.Format")
                continue
            }
            let (target, tolerance) = pair
            let back = try SuiteImageIO.decode(SuiteImageIO.encode(source, as: target), longestSide: nil)
            #expect(back.width == 48 && back.height == 32, "\(format.title) keeps the size")
            let worst = zip(expected, try back.rgba8()).map { abs(Int($0) - Int($1)) }.max() ?? 255
            #expect(worst <= tolerance, "\(format.title) reads back within \(tolerance) levels, worst \(worst)")
        }
    }

    @Test func aSixteenBitTIFFKeepsAThousandthStepThatEightBitsLoses() throws {
        var buffer = try PixelBuffer(width: 2, height: 1)
        try buffer.setPixel(x: 0, y: 0, RGBA(r: 0.5, g: 0.5, b: 0.5, a: 1))
        try buffer.setPixel(x: 1, y: 0, RGBA(r: 0.501, g: 0.5, b: 0.5, a: 1))
        func step(_ bits: Int) throws -> Float {
            let back = try SuiteImageIO.decode(SuiteImageIO.encode(buffer, as: .tiff(bitDepth: bits)), longestSide: nil)
            return try back.pixel(x: 1, y: 0).r - back.pixel(x: 0, y: 0).r
        }
        let deep = try step(16), shallow = try step(8)
        #expect(abs(deep - 0.001) < 0.0002, "16 bits keep the 1/1000 step: \(deep)")
        #expect(abs(shallow - 0.001) > 0.0005, "8 bits can't hold it: \(shallow)")
    }

    @Test func anOpenEXRValueAboveOneSurvivesDecode() throws {
        let bright: [Float] = [2.5, 0.25, 0.1, 1]
        let image = try Self.floatImage(Array([[Float]](repeating: bright, count: 16).joined()), width: 4, height: 4)
        let exr = try SuiteImageIO.encode(image, as: SuiteImageFormat.exr, quality: nil)
        let pixel = try SuiteImageIO.decode(exr, longestSide: nil).pixel(x: 2, y: 2)
        #expect(abs(pixel.r - 2.5) < 0.01, "the value above 1 is kept, not cut at 1: \(pixel)")
        #expect(abs(pixel.g - 0.25) < 0.01 && abs(pixel.b - 0.1) < 0.01)
    }

    @Test func aDisplayP3PNGsRedDecodesOutsideSRGB() throws {
        let red = try SuiteImageIO.decode(ImageIOFixtures.p3RedPNG(), longestSide: nil).pixel(x: 0, y: 0)
        #expect(red.r > 1.1, "P3 red is redder than sRGB's: \(red)")
        #expect(red.g < -0.02 && red.b < 0, "and sits outside sRGB, not clipped onto it: \(red)")
    }

    @Test func aSixteenBitTIFFInDisplayP3ReadsBackWithinAThousandth() throws {
        // Linear sRGB: P3 (0.9, 0.1, 0.1), red above 1 and inside P3; then two in-gamut colours.
        let colours = [RGBA(r: 1.080, g: 0.066, b: 0.084, a: 1), RGBA(r: 0.2, g: 0.5, b: 0.8, a: 1),
                       RGBA(r: 0.9, g: 0.9, b: 0.1, a: 1)]
        var buffer = try PixelBuffer(width: colours.count, height: 1)
        for (x, colour) in colours.enumerated() { try buffer.setPixel(x: x, y: 0, colour) }
        let tiff = try SuiteImageIO.encode(buffer, as: .tiff(bitDepth: 16), profile: .displayP3)
        let back = try SuiteImageIO.decode(tiff, longestSide: nil)
        for (x, colour) in colours.enumerated() {
            let got = try back.pixel(x: x, y: 0)
            let off = max(abs(got.r - colour.r), abs(got.g - colour.g), abs(got.b - colour.b))
            #expect(off < 0.001, "pixel \(x) reads back within 1/1000: \(got) for \(colour)")
        }
    }
}
#endif
