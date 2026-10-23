// ShellMediaFootageTests.swift: shell-media's footage reader on a Mac (MJ-SM3,
// SM-8), in its own suite so ShellMediaReadTests stays SM-7's stills. It
// reads the H.264 that SM-5's MovieWriter writes (48 of ShellMediaWriteTests'
// source frames, 1280 x 720 at 24 fps): the info is 1280 x 720, 24 fps, 48
// frames, 2 s, no alpha, no audio, codec "avc1"; the frame at 1.0 s is source
// frame 24 within 6/255 mean error and is not 23 or 25 (neighbouring source
// frames differ by more than 20/255 by construction); a shrink keeps the
// aspect; a missing file throws. macOS only.
import Foundation
import SuiteModel
import SuiteShell
import Testing

@Suite(.timeLimit(.minutes(5))) struct ShellMediaFootageTests {
    typealias Write = ShellMediaWriteTests

    static let settings = MovieSettings(width: 1280, height: 720, fps: 24, codec: .h264, quality: 0.9)

    /// SM-5's 48-frame H.264 at a fresh scratch path; `Write.discard(_:)` removes it.
    static func footage() async throws -> URL {
        let url = try Write.scratch("footage.mov")
        try await Write.writeMovie(settings, frames: 48, to: url)
        return url
    }

    /// The mean per-channel R, G, B difference, in 255ths, between `frame`
    /// and `source` drawn over black (how H.264 writes it).
    static func meanError(_ frame: MediaFrame, _ source: MediaFrame) -> Double {
        guard frame.rgba.count == source.rgba.count, !frame.rgba.isEmpty else { return 255 }
        var total = 0
        for i in stride(from: 0, to: source.rgba.count, by: 4) {
            let a = Int(source.rgba[i + 3])
            for c in 0..<3 { total += abs(Int(frame.rgba[i + c]) - (Int(source.rgba[i + c]) * a + 127) / 255) }
        }
        return Double(total) / Double(source.rgba.count / 4 * 3)
    }

    @Test func h264InfoReadsBack() async throws {
        let url = try await Self.footage()
        defer { Write.discard(url) }
        let info = try await FootageReader().info(ofMovieAt: url.path)
        #expect(info.width == 1280 && info.height == 720)
        #expect(abs(info.fps - 24) < 0.01, "fps \(info.fps)")
        #expect(info.frameCount == 48)
        #expect(abs(info.seconds - 2) <= 0.001, "seconds \(info.seconds)")
        #expect(!info.hasAlpha && !info.hasAudio)
        #expect(info.codec == "avc1")
    }

    @Test func frameAtOneSecondIsSourceFrameTwentyFour() async throws {
        let url = try await Self.footage()
        defer { Write.discard(url) }
        let frame = try await FootageReader().frame(ofMovieAt: url.path, seconds: 1.0, longestSide: nil)
        #expect(frame.width == 1280 && frame.height == 720)
        let source = { (i: Int) throws in try Write.sourceFrame(i, width: 1280, height: 720) }
        let errors = try [23, 24, 25].map { Self.meanError(frame, try source($0)) }
        #expect(errors[1] <= 6, "frame 24 differs by \(errors[1])")
        #expect(errors[0] > 6, "not the frame before")
        #expect(errors[2] > 6, "not the frame after")
    }

    @Test func shrinkKeepsTheAspect() async throws {
        let url = try await Self.footage()
        defer { Write.discard(url) }
        let frame = try await FootageReader().frame(ofMovieAt: url.path, seconds: 0.5, longestSide: 320)
        #expect(frame.width == 320 && frame.height == 180)
    }

    @Test func missingMovieThrows() async {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("no-such-\(UUID().uuidString).mov").path
        await #expect(throws: SuiteError.self) { _ = try await FootageReader().info(ofMovieAt: path) }
        await #expect(throws: SuiteError.self) {
            _ = try await FootageReader().frame(ofMovieAt: path, seconds: 0, longestSide: nil)
        }
    }
}
