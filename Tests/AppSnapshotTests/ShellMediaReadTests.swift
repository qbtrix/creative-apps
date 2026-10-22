// ShellMediaReadTests.swift: shell-media's still decoder on a Mac (MJ-SM3),
// written first by SM-2 and disabled until SM-7 fills the `still` seam. The
// stills in Fixtures/media/ (made by a script, 32 x 16 or 16 x 8, upright
// quadrants red, green / blue, white): the EXIF-orientation-6 JPEG decodes
// upright, the HEIC decodes, the PNG keeps straight alpha, and a shrink keeps
// the aspect and never enlarges. macOS only.
import Foundation
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(5))) struct ShellMediaReadTests {
    /// SM-7 makes this `try StillDecoder().still(data, longestSide: longestSide)`; it throws until then.
    static func still(_ data: Data, longestSide: Int?) throws(SuiteError) -> MediaFrame {
        throw .notAvailable("waits on SM-7")
    }

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

    /// Whether `rgba` is within 40 of `expected` on each colour channel.
    static func near(_ rgba: [Int], _ expected: [Int]) -> Bool {
        rgba.count >= 3 && zip(rgba, expected).allSatisfy { abs($0 - $1) <= 40 }
    }

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
}
