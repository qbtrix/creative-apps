// ShellMediaReadTests.swift: shell-media's live readers on a Mac (MJ-SM3),
// written first by SM-2 and disabled by the task that enables each case.
// Stills (SM-7), from Fixtures/media/ (made by a script, each 32 x 16 or
// 16 x 8, upright quadrants red, green / blue, white): the EXIF-orientation-6
// JPEG decodes upright, the HEIC decodes, the PNG keeps straight alpha, and a
// shrink keeps the aspect. Footage (SM-8), reading the H.264 that
// ShellMediaWriteTests writes: 1280 x 720, 24 fps, 48 frames, no alpha, no
// audio, and the frame at 1.0 s is source frame 24 within 6/255. macOS only.
import Foundation
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(5))) struct ShellMediaReadTests {
    // MARK: Seams the enabling tasks fill (each throws until then).

    /// SM-7: `try StillDecoder().still(data, longestSide: longestSide)`.
    static func still(_ data: Data, longestSide: Int?) throws(SuiteError) -> MediaFrame {
        throw .notAvailable("waits on SM-7")
    }

    /// SM-8: `try await FootageReader().info(ofMovieAt: path)`.
    static func info(ofMovieAt path: String) async throws(SuiteError) -> MediaInfo {
        throw .notAvailable("waits on SM-8")
    }

    /// SM-8: `try await FootageReader().frame(ofMovieAt: path, seconds: seconds, longestSide: nil)`.
    static func frame(ofMovieAt path: String, seconds: Double) async throws(SuiteError) -> MediaFrame {
        throw .notAvailable("waits on SM-8")
    }

    // MARK: Helpers

    static func fixture(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/media").appendingPathComponent(name)
        return try Data(contentsOf: url)
    }

    /// The R, G, B, A of pixel (x, y), top row first.
    static func pixel(_ frame: MediaFrame, _ x: Int, _ y: Int) -> [Int] {
        let i = (y * frame.width + x) * 4
        guard i >= 0, i + 4 <= frame.rgba.count else { return [] }
        return frame.rgba[i..<i + 4].map { Int($0) }
    }

    /// Whether `rgb` is within 40 of `expected` on each channel.
    static func near(_ rgba: [Int], _ expected: [Int]) -> Bool {
        rgba.count >= 3 && zip(rgba, expected).allSatisfy { abs($0 - $1) <= 40 }
    }

    /// The mean per-channel R, G, B difference, in 255ths, between `frame`
    /// and `source` composited over black.
    static func meanError(_ frame: MediaFrame, _ source: MediaFrame) -> Double {
        guard frame.rgba.count == source.rgba.count, !frame.rgba.isEmpty else { return 255 }
        var total = 0
        for i in stride(from: 0, to: source.rgba.count, by: 4) {
            let a = Int(source.rgba[i + 3])
            for c in 0..<3 { total += abs(Int(frame.rgba[i + c]) - (Int(source.rgba[i + c]) * a + 127) / 255) }
        }
        return Double(total) / Double(source.rgba.count / 4 * 3)
    }

    // MARK: Stills (SM-7)

    @Test(.disabled("waits on SM-7")) func rotatedJPEGDecodesUpright() throws {
        let frame = try Self.still(try Self.fixture("rotated-orientation6.jpg"), longestSide: nil)
        #expect(frame.width == 32 && frame.height == 16)
        #expect(Self.near(Self.pixel(frame, 0, 0), [255, 0, 0]), "top-left is red")
        #expect(Self.near(Self.pixel(frame, 31, 0), [0, 255, 0]), "top-right is green")
        #expect(Self.near(Self.pixel(frame, 0, 15), [0, 0, 255]), "bottom-left is blue")
    }

    @Test(.disabled("waits on SM-7")) func heicDecodes() throws {
        let frame = try Self.still(try Self.fixture("quadrants.heic"), longestSide: nil)
        #expect(frame.width == 32 && frame.height == 16)
        #expect(Self.near(Self.pixel(frame, 0, 0), [255, 0, 0]))
        #expect(Self.near(Self.pixel(frame, 31, 15), [255, 255, 255]))
    }

    @Test(.disabled("waits on SM-7")) func pngKeepsStraightAlpha() throws {
        let frame = try Self.still(try Self.fixture("half-transparent.png"), longestSide: nil)
        #expect(frame.width == 16 && frame.height == 8)
        #expect(Self.pixel(frame, 0, 0) == [255, 0, 0, 255])
        #expect(Self.pixel(frame, 15, 7).last == 0, "the right half is transparent")
    }

    @Test(.disabled("waits on SM-7")) func shrinkKeepsAspect() throws {
        let data = try Self.fixture("rotated-orientation6.jpg")
        let small = try Self.still(data, longestSide: 8)
        #expect(small.width == 8 && small.height == 4)
        #expect(Self.near(Self.pixel(small, 0, 0), [255, 0, 0]), "shrunk upright")
        let unchanged = try Self.still(data, longestSide: 512)
        #expect(unchanged.width == 32 && unchanged.height == 16, "never enlarged")
    }

    @Test(.disabled("waits on SM-7")) func notAnImageThrows() {
        #expect(throws: SuiteError.self) { try Self.still(Data("not an image".utf8), longestSide: nil) }
    }

    // MARK: Footage (SM-8), reading SM-5's H.264

    static let movie = MovieSettings(width: 1280, height: 720, fps: 24, codec: .h264, quality: 0.9)

    @Test(.disabled("waits on SM-8")) func h264InfoReadsBack() async throws {
        let dir = try ShellMediaWriteTests.folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("footage.mov")
        try await ShellMediaWriteTests.writeMovie(Self.movie, frames: 48, to: url)
        let info = try await Self.info(ofMovieAt: url.path)
        #expect(info.width == 1280 && info.height == 720)
        #expect(info.fps == 24 && info.frameCount == 48 && abs(info.seconds - 2) <= 0.001)
        #expect(!info.hasAlpha && !info.hasAudio && info.codec == "avc1")
    }

    @Test(.disabled("waits on SM-8")) func frameAtOneSecondIsSourceFrameTwentyFour() async throws {
        let dir = try ShellMediaWriteTests.folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("footage.mov")
        try await ShellMediaWriteTests.writeMovie(Self.movie, frames: 48, to: url)
        let frame = try await Self.frame(ofMovieAt: url.path, seconds: 1.0)
        let source = { (i: Int) throws in try ShellMediaWriteTests.sourceFrame(i, width: 1280, height: 720) }
        #expect(Self.meanError(frame, try source(24)) <= 6)
        #expect(Self.meanError(frame, try source(23)) > 6, "not the frame before")
        #expect(Self.meanError(frame, try source(25)) > 6, "not the frame after")
    }
}
