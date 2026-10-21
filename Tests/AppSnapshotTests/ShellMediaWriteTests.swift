// ShellMediaWriteTests.swift: shell-media's live writers on a Mac (MJ-SM2),
// written first by SM-2 and disabled by the task that enables each case.
// Movies (SM-5): a 48-frame 24 fps 1280 x 720 H.264 is 2.000 s with BT.709
// tags, each codec writes its track codec, ProRes 4444 and HEVC with alpha
// keep a transparent corner, cancel leaves no file, and 1080p throughput is
// reported. Animated images and stills (SM-6): a 10-frame 25 fps GIF loops
// forever with 4 cs delays, APNG keeps alpha, each still format reads back
// its size. Reads back with AVFoundation and ImageIO only. macOS only.
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ImageIO
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(5))) struct ShellMediaWriteTests {
    // MARK: Seams the enabling tasks fill (each throws until then).

    /// SM-5: `try MovieWriter(...)` for `path` and `settings`.
    static func movie(at path: String, _ settings: MovieSettings) throws(SuiteError) -> any FrameSink {
        throw .notAvailable("waits on SM-5")
    }

    /// SM-6: `try AnimatedImageWriter(...)` for `path` and `settings`.
    static func animatedImage(at path: String, _ settings: AnimatedImageSettings) throws(SuiteError) -> any FrameSink {
        throw .notAvailable("waits on SM-6")
    }

    /// SM-6: `try StillEncoder().still(frame, as: format, quality: quality)`.
    static func still(_ frame: MediaFrame, as format: StillFormat, quality: Double) throws(SuiteError) -> Data {
        throw .notAvailable("waits on SM-6")
    }

    // MARK: Fixtures shared with ShellMediaReadTests.

    /// Source frame `i`: one flat colour that moves 37 levels a frame (so
    /// neighbours differ by more than 20/255), with a transparent 16 x 16
    /// top-left corner.
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

    /// A fresh, empty folder for one test's files.
    static func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShellMediaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes source frames 0..<frames as a movie at `url`.
    static func writeMovie(_ settings: MovieSettings, frames: Int, to url: URL) async throws {
        let sink = try movie(at: url.path, settings)
        for i in 0..<frames { try sink.append(try sourceFrame(i, width: settings.width, height: settings.height)) }
        try await sink.finish()
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

    @Test(.disabled("waits on SM-5")) func h264IsTwoSecondsWithBT709Tags() async throws {
        let dir = try Self.folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("h264.mov")
        try await Self.writeMovie(MovieSettings(width: 1280, height: 720, fps: 24, codec: .h264, quality: 0.8),
                                  frames: 48, to: url)
        let duration = try await AVURLAsset(url: url).load(.duration)
        #expect(abs(duration.seconds - 2.0) <= 0.001)
        let format = try await Self.videoFormat(url)
        let tags: [(CFString, CFString)] = [
            (kCMFormatDescriptionExtension_ColorPrimaries, kCMFormatDescriptionColorPrimaries_ITU_R_709_2),
            (kCMFormatDescriptionExtension_TransferFunction, kCMFormatDescriptionTransferFunction_ITU_R_709_2),
            (kCMFormatDescriptionExtension_YCbCrMatrix, kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2),
        ]
        for (key, value) in tags {
            let tag = CMFormatDescriptionGetExtension(format, extensionKey: key) as? String
            #expect(tag == value as String, "\(key)")
        }
    }

    @Test(.disabled("waits on SM-5"), arguments: MovieCodec.allCases)
    func eachCodecWritesItsTrackCodec(_ codec: MovieCodec) async throws {
        let expected: [MovieCodec: CMVideoCodecType] = [
            .h264: kCMVideoCodecType_H264, .hevc: kCMVideoCodecType_HEVC,
            .hevcAlpha: kCMVideoCodecType_HEVCWithAlpha, .prores4444: kCMVideoCodecType_AppleProRes4444,
        ]
        let dir = try Self.folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("\(codec.rawValue).mov")
        try await Self.writeMovie(MovieSettings(width: 64, height: 64, fps: 24, codec: codec, quality: 0.8),
                                  frames: 4, to: url)
        let format = try await Self.videoFormat(url)
        #expect(CMFormatDescriptionGetMediaSubType(format) == expected[codec])
    }

    @Test(.disabled("waits on SM-5"), arguments: [MovieCodec.prores4444, .hevcAlpha])
    func alphaCodecsKeepATransparentCorner(_ codec: MovieCodec) async throws {
        let dir = try Self.folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("\(codec.rawValue).mov")
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

    @Test(.disabled("waits on SM-5")) func cancelLeavesNoFile() throws {
        let dir = try Self.folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("cancelled.mov")
        let sink = try Self.movie(at: url.path, MovieSettings(width: 64, height: 64, fps: 24, codec: .h264, quality: 0.8))
        for i in 0..<3 { try sink.append(try Self.sourceFrame(i, width: 64, height: 64)) }
        sink.cancel()
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    /// Reported, not asserted: 1080p H.264 frames per second (budget >= 60 on Apple silicon, release).
    @Test(.disabled("waits on SM-5")) func throughput() async throws {
        let dir = try Self.folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let frames = 120
        let clock = ContinuousClock()
        let took = try await clock.measure {
            try await Self.writeMovie(MovieSettings(width: 1920, height: 1080, fps: 24, codec: .h264, quality: 0.8),
                                      frames: frames, to: dir.appendingPathComponent("throughput.mov"))
        }
        let seconds = Double(took.components.seconds) + Double(took.components.attoseconds) / 1e18
        print("ShellMediaWriteTests.throughput: \(Double(frames) / max(seconds, 1e-9)) frames/s at 1080p H.264")
    }

    // MARK: Animated images and stills (SM-6)

    /// The file properties of the image at `url` under `dictionary`, and of each frame.
    static func imageProperties(_ url: URL, _ dictionary: CFString) throws -> (file: [CFString: Any], frames: [[CFString: Any]]) {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let file = (CGImageSourceCopyProperties(source, nil) as? [CFString: Any])?[dictionary] as? [CFString: Any]
        let frames = (0..<CGImageSourceGetCount(source)).map { i in
            (CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any])?[dictionary] as? [CFString: Any] ?? [:]
        }
        return (file ?? [:], frames)
    }

    @Test(.disabled("waits on SM-6")) func gifLoopsForeverWithFourCentisecondDelays() async throws {
        let dir = try Self.folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("loop.gif")
        let sink = try Self.animatedImage(at: url.path, AnimatedImageSettings(width: 32, height: 32, fps: 25, format: .gif, loopCount: 0))
        for i in 0..<10 { try sink.append(try Self.sourceFrame(i, width: 32, height: 32)) }
        try await sink.finish()
        let (file, frames) = try Self.imageProperties(url, kCGImagePropertyGIFDictionary)
        #expect(file[kCGImagePropertyGIFLoopCount] as? Int == 0)
        #expect(frames.count == 10)
        for delay in frames.map({ $0[kCGImagePropertyGIFUnclampedDelayTime] as? Double }) {
            #expect(abs((delay ?? 0) - 0.04) < 0.0005)
        }
    }

    @Test(.disabled("waits on SM-6")) func apngKeepsAlphaAndLoopCount() async throws {
        let dir = try Self.folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("alpha.png")
        let sink = try Self.animatedImage(at: url.path, AnimatedImageSettings(width: 32, height: 32, fps: 12, format: .apng, loopCount: 3))
        for i in 0..<4 { try sink.append(try Self.sourceFrame(i, width: 32, height: 32)) }
        try await sink.finish()
        let (file, frames) = try Self.imageProperties(url, kCGImagePropertyPNGDictionary)
        #expect(file[kCGImagePropertyAPNGLoopCount] as? Int == 3)
        #expect(frames.count == 4)
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let pixels = try #require(Self.rgba(try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))))
        #expect(pixels[3] == 0 && pixels[(20 * 32 + 20) * 4 + 3] == 255)
    }

    @Test(.disabled("waits on SM-6"), arguments: StillFormat.allCases)
    func eachStillReadsBackItsSize(_ format: StillFormat) throws {
        let data = try Self.still(try Self.sourceFrame(5, width: 48, height: 24), as: format, quality: 0.9)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 48 && image.height == 24)
        if format == .png || format == .tiff {
            #expect(Self.rgba(image)?[3] == 0, "\(format) keeps the transparent corner")
        }
    }
}
