// ShellMediaWriteTests.swift: shell-media's movie writer on a Mac (MJ-SM2),
// written first by SM-2; SM-5 fills the `movie` seam with SuiteShell's
// `MovieWriter` and turns the movie cases on. A
// 48-frame 24 fps 1280 x 720 H.264 is 2.000 s with BT.709 tags, each codec
// writes its track codec, the alpha codecs keep a transparent corner, cancel
// leaves no file, and 1080p throughput is reported. Reads back with
// AVFoundation only. macOS only.
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import SuiteModel
import SuiteShell
import Testing

@Suite(.timeLimit(.minutes(5))) struct ShellMediaWriteTests {
    /// The movie writer under test: shell-media's `MovieWriter` for `path` and `settings`.
    static func movie(at path: String, _ settings: MovieSettings) throws(SuiteError) -> any FrameSink {
        try MovieWriter(path: path, settings)
    }

    // MARK: Helpers, also for SM-6's and SM-8's suites.

    /// Source frame `i`: one flat colour that moves 37 levels a frame (so
    /// neighbours differ by more than 20/255), with a transparent 16 x 16 top-left corner.
    static func sourceFrame(_ i: Int, width: Int, height: Int) throws -> MediaFrame {
        let g = UInt8((i * 37) % 256)
        let row = Array([[UInt8]](repeating: [g, 255 - g, 128, 255], count: width).joined())
        let corner = min(16, width, height)
        let cornerRow = [UInt8](repeating: 0, count: corner * 4) + row.dropFirst(corner * 4)
        var rgba: [UInt8] = []
        rgba.reserveCapacity(width * height * 4)
        for y in 0..<height { rgba += y < corner ? cornerRow : row }
        return try MediaFrame(width: width, height: height, rgba: rgba)
    }

    /// `name` inside a fresh, empty folder; `discard(_:)` removes that folder.
    static func scratch(_ name: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ShellMedia-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }

    static func discard(_ url: URL) { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    /// Appends source frames 0..<frames to `sink`, then finishes it.
    static func fill(_ sink: any FrameSink, frames: Int, width: Int, height: Int) async throws {
        for i in 0..<frames { try sink.append(try sourceFrame(i, width: width, height: height)) }
        try await sink.finish()
    }

    static func writeMovie(_ settings: MovieSettings, frames: Int, to url: URL) async throws {
        let sink = try movie(at: url.path, settings)
        try await fill(sink, frames: frames, width: settings.width, height: settings.height)
    }

    /// `image` drawn into 8-bit sRGB R, G, B, A bytes (premultiplied), top row first.
    static func rgba(_ image: CGImage) -> [UInt8]? {
        let w = image.width, h = image.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var out = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = out.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                          bytesPerRow: w * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return drawn ? out : nil
    }

    /// The first video track's format description in the movie at `url`.
    static func videoFormat(_ url: URL) async throws -> CMFormatDescription {
        let tracks = try await AVURLAsset(url: url).loadTracks(withMediaType: .video)
        let track = try #require(tracks.first)
        let formats = try await track.load(.formatDescriptions)
        return try #require(formats.first)
    }

    // MARK: Movies (SM-5)

    @Test func h264IsTwoSecondsWithBT709Tags() async throws {
        let url = try Self.scratch("h264.mov")
        defer { Self.discard(url) }
        try await Self.writeMovie(MovieSettings(width: 1280, height: 720, fps: 24, codec: .h264, quality: 0.8),
                                  frames: 48, to: url)
        let duration = try await AVURLAsset(url: url).load(.duration)
        #expect(abs(duration.seconds - 2.0) <= 0.001)
        let format = try await Self.videoFormat(url)
        for (key, value) in [
            (kCMFormatDescriptionExtension_ColorPrimaries, kCMFormatDescriptionColorPrimaries_ITU_R_709_2),
            (kCMFormatDescriptionExtension_TransferFunction, kCMFormatDescriptionTransferFunction_ITU_R_709_2),
            (kCMFormatDescriptionExtension_YCbCrMatrix, kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2),
        ] {
            #expect(CMFormatDescriptionGetExtension(format, extensionKey: key) as? String == value as String, "\(key)")
        }
    }

    @Test(arguments: MovieCodec.allCases)
    func eachCodecWritesItsTrackCodec(_ codec: MovieCodec) async throws {
        let expected: [MovieCodec: CMVideoCodecType] = [
            .h264: kCMVideoCodecType_H264, .hevc: kCMVideoCodecType_HEVC,
            .hevcAlpha: kCMVideoCodecType_HEVCWithAlpha, .prores4444: kCMVideoCodecType_AppleProRes4444,
        ]
        let url = try Self.scratch("\(codec.rawValue).mov")
        defer { Self.discard(url) }
        try await Self.writeMovie(MovieSettings(width: 64, height: 64, fps: 24, codec: codec, quality: 0.8),
                                  frames: 4, to: url)
        let format = try await Self.videoFormat(url)
        #expect(CMFormatDescriptionGetMediaSubType(format) == expected[codec])
    }

    @Test(arguments: [MovieCodec.prores4444, .hevcAlpha])
    func alphaCodecsKeepATransparentCorner(_ codec: MovieCodec) async throws {
        let url = try Self.scratch("\(codec.rawValue).mov")
        defer { Self.discard(url) }
        try await Self.writeMovie(MovieSettings(width: 64, height: 64, fps: 24, codec: codec, quality: 1),
                                  frames: 2, to: url)
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: .zero).image
        let pixels = try #require(Self.rgba(image))
        #expect(pixels[3] <= 8, "corner alpha \(pixels[3])")
        #expect(pixels[(32 * 64 + 32) * 4 + 3] >= 247, "middle stays opaque")
    }

    @Test func cancelLeavesNoFile() throws {
        let url = try Self.scratch("cancelled.mov")
        defer { Self.discard(url) }
        let sink = try Self.movie(at: url.path, MovieSettings(width: 64, height: 64, fps: 24, codec: .h264, quality: 0.8))
        for i in 0..<3 { try sink.append(try Self.sourceFrame(i, width: 64, height: 64)) }
        sink.cancel()
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    /// Reported, not asserted: 1080p H.264 frames per second (budget >= 60 on Apple silicon, release).
    @Test func throughput() async throws {
        let url = try Self.scratch("throughput.mov")
        defer { Self.discard(url) }
        let settings = MovieSettings(width: 1920, height: 1080, fps: 24, codec: .h264, quality: 0.8)
        let took = try await ContinuousClock().measure { try await Self.writeMovie(settings, frames: 120, to: url) }
        let seconds = Double(took.components.seconds) + Double(took.components.attoseconds) / 1e18
        print("ShellMediaWriteTests.throughput: \(120 / max(seconds, 1e-9)) frames/s at 1080p H.264")
    }
}
