// ShellMediaLiveTests.swift: the live media slot on a Mac (MJ-SM4, SM-9).
// `SuiteServices.live` holds shell-media's `LiveMedia`, so `pending` has no
// `media` key, and through `services.media` alone every movie codec this Mac
// writes reads back at its size, rate and frame count with a frame at its
// size, each animated format reads back as a still, and each still format
// decodes at its size. Uses ShellMediaWriteTests' source frames and scratch
// folders. macOS only.
import Foundation
import SuiteModel
import SuiteShell
import Testing

@Suite(.timeLimit(.minutes(5))) struct ShellMediaLiveTests {
    typealias Write = ShellMediaWriteTests

    static func live() -> SuiteServices {
        let support = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShellMediaLiveTests-\(UUID().uuidString)").path
        return SuiteServices.live(support: support, app: .launcher, arguments: [])
    }

    @Test func mediaIsLiveAndNotPending() {
        let s = Self.live()
        #expect(s.pending["media"] == nil)
        #expect(s.media is LiveMedia)
        #expect(s.media.movieCodecs == MovieWriter.codecs)
        #expect(s.media.movieCodecs.contains(.h264))
    }

    @Test func everyMovieCodecWritesAndReadsBack() async throws {
        let media = Self.live().media
        for codec in media.movieCodecs {
            let url = try Write.scratch("live-\(codec.rawValue).mov")
            defer { Write.discard(url) }
            let settings = MovieSettings(width: 64, height: 48, fps: 12, codec: codec, quality: 0.8)
            try await Write.fill(try media.movie(at: url.path, settings), frames: 12, width: 64, height: 48)
            let info = try await media.info(ofMovieAt: url.path)
            #expect(info.width == 64 && info.height == 48, "\(codec)")
            #expect(abs(info.fps - 12) < 0.01, "\(codec) fps \(info.fps)")
            #expect(info.frameCount == 12, "\(codec)")
            #expect(!info.codec.isEmpty, "\(codec)")
            let frame = try await media.frame(ofMovieAt: url.path, seconds: 0.5, longestSide: nil)
            #expect(frame.width == 64 && frame.height == 48, "\(codec)")
        }
    }

    @Test(arguments: AnimatedImageFormat.allCases)
    func everyAnimatedFormatWritesAndReadsBack(_ format: AnimatedImageFormat) async throws {
        let media = Self.live().media
        let url = try Write.scratch(format == .gif ? "live.gif" : "live.png")
        defer { Write.discard(url) }
        let settings = AnimatedImageSettings(width: 32, height: 24, fps: 10, format: format, loopCount: 0)
        try await Write.fill(try media.animatedImage(at: url.path, settings), frames: 5, width: 32, height: 24)
        let first = try media.still(try Data(contentsOf: url), longestSide: nil)
        #expect(first.width == 32 && first.height == 24)
    }

    @Test(arguments: StillFormat.allCases)
    func everyStillFormatWritesAndReadsBack(_ format: StillFormat) throws {
        let media = Self.live().media
        let data = try media.still(try Write.sourceFrame(3, width: 40, height: 30), as: format, quality: 0.9)
        let read = try media.still(data, longestSide: nil)
        #expect(read.width == 40 && read.height == 30)
    }
}
