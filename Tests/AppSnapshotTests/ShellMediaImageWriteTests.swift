// ShellMediaImageWriteTests.swift: shell-media's animated image and still
// writers on a Mac (MJ-SM2, SM-6), in their own suite so the movie cases in
// ShellMediaWriteTests stay SM-5's. A GIF with loop count 0 reads back as
// looping forever, each frame's delay is FrameClock's (25 fps all 4 cs, 30 fps
// 3 and 4 cs summing to the true time), an APNG keeps its loop count, its
// 1 / fps delays and a transparent corner, cancel leaves no file, and each
// still format reads back at its size (PNG and TIFF with the corner still
// transparent). Uses ShellMediaWriteTests' source frames and scratch folders;
// reads back with ImageIO only. macOS only.
import CoreGraphics
import Foundation
import ImageIO
import SuiteModel
import SuiteShell
import Testing

@Suite(.timeLimit(.minutes(5))) struct ShellMediaImageWriteTests {
    typealias Write = ShellMediaWriteTests

    /// The file-level and per-frame properties of the image at `url` under `dictionary`.
    static func properties(_ url: URL, _ dictionary: CFString) throws -> (file: [CFString: Any], frames: [[CFString: Any]]) {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let file = (CGImageSourceCopyProperties(source, nil) as? [CFString: Any])?[dictionary] as? [CFString: Any]
        let frames = (0..<CGImageSourceGetCount(source)).map { i in
            (CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any])?[dictionary] as? [CFString: Any] ?? [:]
        }
        return (file ?? [:], frames)
    }

    static func writeAnimation(_ settings: AnimatedImageSettings, frames: Int, to url: URL) async throws {
        let sink = try AnimatedImageWriter(path: url.path, settings)
        try await Write.fill(sink, frames: frames, width: settings.width, height: settings.height)
    }

    // MARK: GIF

    @Test func gifLoopCountZeroReadsAsForever() async throws {
        let url = try Write.scratch("forever.gif")
        defer { Write.discard(url) }
        try await Self.writeAnimation(AnimatedImageSettings(width: 32, height: 32, fps: 25, format: .gif, loopCount: 0),
                                      frames: 10, to: url)
        let (file, frames) = try Self.properties(url, kCGImagePropertyGIFDictionary)
        #expect(file[kCGImagePropertyGIFLoopCount] as? Int == 0)
        #expect(frames.count == 10)
    }

    @Test(arguments: [25, 30])
    func gifDelaysAreFrameClocks(_ fps: Int) async throws {
        let url = try Write.scratch("delays-\(fps).gif")
        defer { Write.discard(url) }
        let count = 2 * fps
        try await Self.writeAnimation(AnimatedImageSettings(width: 32, height: 32, fps: fps, format: .gif, loopCount: 0),
                                      frames: count, to: url)
        var clock = try FrameClock(fps: fps)
        let expected = (0..<count).map { _ in clock.nextGIFDelay() }
        let read = try Self.properties(url, kCGImagePropertyGIFDictionary).frames.map {
            Int((($0[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? -1) * 100 + 0.5)
        }
        #expect(read == expected)
        #expect(read.reduce(0, +) == 200, "two seconds of frames last 200 cs")
    }

    // MARK: APNG

    @Test func apngKeepsAlphaLoopCountAndDelays() async throws {
        let url = try Write.scratch("alpha.png")
        defer { Write.discard(url) }
        try await Self.writeAnimation(AnimatedImageSettings(width: 32, height: 32, fps: 12, format: .apng, loopCount: 3),
                                      frames: 4, to: url)
        let (file, frames) = try Self.properties(url, kCGImagePropertyPNGDictionary)
        #expect(file[kCGImagePropertyAPNGLoopCount] as? Int == 3)
        #expect(frames.count == 4)
        for delay in frames.map({ $0[kCGImagePropertyAPNGUnclampedDelayTime] as? Double }) {
            #expect(abs((delay ?? 0) - 1.0 / 12) < 0.001)
        }
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let pixels = try #require(Write.rgba(image))
        #expect(pixels[3] == 0, "the corner stays transparent")
        #expect(pixels[(20 * 32 + 20) * 4 + 3] == 255, "the middle stays opaque")
    }

    // MARK: Refusals and cancel

    @Test func wrongSizedFrameThrows() throws {
        let url = try Write.scratch("size.gif")
        defer { Write.discard(url) }
        let sink = try AnimatedImageWriter(
            path: url.path, AnimatedImageSettings(width: 32, height: 32, fps: 10, format: .gif, loopCount: 0))
        #expect(throws: SuiteError.self) { try sink.append(try Write.sourceFrame(0, width: 16, height: 16)) }
        sink.cancel()
    }

    @Test func cancelLeavesNoFile() throws {
        let url = try Write.scratch("cancelled.png")
        defer { Write.discard(url) }
        let sink = try AnimatedImageWriter(
            path: url.path, AnimatedImageSettings(width: 32, height: 32, fps: 10, format: .apng, loopCount: 0))
        for i in 0..<3 { try sink.append(try Write.sourceFrame(i, width: 32, height: 32)) }
        sink.cancel()
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: Stills

    @Test(arguments: StillFormat.allCases)
    func eachStillReadsBackItsSize(_ format: StillFormat) throws {
        let data = try StillEncoder().still(try Write.sourceFrame(5, width: 48, height: 24), as: format, quality: 0.9)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 48 && image.height == 24)
        if format == .png || format == .tiff {
            #expect(Write.rgba(image)?[3] == 0, "\(format) keeps the transparent corner")
        }
        if format == .jpeg {
            #expect(Write.rgba(image)?[3] == 255, "JPEG is opaque")
        }
    }
}
