// ShellTextDrawTests.swift: shell-text ST-7 (MJ-ST3, packet
// suite/features/shell-text.md). GlyphRasterizer draws each grapheme at its
// baseline origin (frame space: y down, top row first) turned by its angle
// (degrees clockwise on screen): an upright "H" sits on its baseline right of
// its origin; a line drawn at 45° covers pixels along the diagonal and none at
// the opposite corners; colour comes back as straight-alpha sRGB bytes; no
// spans is a clear frame; a size it can't draw throws. titleFrameFast reports
// its time (Mac finisher), it asserts no budget. macOS only.
#if os(macOS)
import Foundation
import SuiteModel
import SuiteShell
import Testing

@Suite(.timeLimit(.minutes(1))) struct ShellTextDrawTests {
    let rasterizer = GlyphRasterizer()

    /// `span` laid out from `start` along `degrees` (clockwise, y down) by its measured advances.
    private func placed(_ span: TextSpan, from start: SuitePoint, degrees: Double) throws -> PlacedSpan {
        let metrics = try #require(try CoreTextMeasurer().measure([span]).first)
        let radians = degrees * .pi / 180
        var origins: [SuitePoint] = [], distance = 0.0
        for advance in metrics.advances {
            origins.append(SuitePoint(x: start.x + distance * cos(radians), y: start.y + distance * sin(radians)))
            distance += advance
        }
        return PlacedSpan(span: span, origins: origins, degrees: Array(repeating: degrees, count: origins.count))
    }

    /// Each pixel with any alpha, as (x, y) with y down.
    private func ink(_ frame: MediaFrame) -> [(x: Int, y: Int)] {
        var out: [(x: Int, y: Int)] = []
        for y in 0..<frame.height {
            for x in 0..<frame.width {
                let alpha = (y * frame.width + x) * 4 + 3
                if frame.rgba.indices.contains(alpha), frame.rgba[alpha] > 0 { out.append((x, y)) }
            }
        }
        return out
    }

    @Test func noSpansIsAClearFrame() throws {
        let frame = try rasterizer.draw([], width: 64, height: 32)
        #expect(frame.width == 64 && frame.height == 32)
        #expect(frame.rgba.count == 64 * 32 * 4 && frame.rgba.allSatisfy { $0 == 0 })
    }

    @Test func aSizeItCantDrawThrows() {
        #expect(throws: SuiteError.self) { try rasterizer.draw([], width: 0, height: 10) }
        #expect(throws: SuiteError.self) { try rasterizer.draw([], width: 1 << 20, height: 1 << 20) }
    }

    @Test func uprightGlyphSitsOnItsBaseline() throws {
        let span = TextSpan("H", fontFamily: "Helvetica", fontSize: 40)
        let frame = try rasterizer.draw([try placed(span, from: SuitePoint(x: 50, y: 60), degrees: 0)],
                                        width: 120, height: 100)
        let pixels = ink(frame)
        let xs = pixels.map(\.x), ys = pixels.map(\.y)
        let minX = try #require(xs.min()), maxX = try #require(xs.max())
        let minY = try #require(ys.min()), maxY = try #require(ys.max())
        #expect(maxY <= 60 && maxY >= 57, "the H's foot sits on the baseline at y 60")
        #expect(minY >= 20 && minY <= 35, "the H's top is a cap height above the baseline")
        #expect(minX >= 50 && minX <= 56 && maxX <= 85, "the H starts at its origin and runs right")
    }

    @Test func fortyFiveDegreesFollowsTheDiagonal() throws {
        let span = TextSpan("HHHHHHHHHH", fontFamily: "Helvetica", fontSize: 20)
        let frame = try rasterizer.draw([try placed(span, from: SuitePoint(x: 20, y: 30), degrees: 45)],
                                        width: 200, height: 200)
        let pixels = ink(frame)
        #expect(pixels.count > 200)
        // The baseline is y = x + 10; caps rise toward the upper right, so ink sits in a band beside it.
        #expect(pixels.allSatisfy { $0.x - $0.y > -14 && $0.x - $0.y < 24 })
        #expect(pixels.contains { $0.x > 100 && $0.y > 100 }, "the line runs down the diagonal")
        #expect(!pixels.contains { $0.x < 40 && $0.y > 160 }, "no ink at the bottom-left corner")
        #expect(!pixels.contains { $0.x > 160 && $0.y < 40 }, "no ink at the top-right corner")
    }

    @Test func colourIsStraightAlphaSRGB() throws {
        let red = TextSpan("H", fontFamily: "Helvetica", fontSize: 80, rgba: [255, 0, 0, 255])
        let halfBlue = TextSpan("H", fontFamily: "Helvetica", fontSize: 80, rgba: [0, 0, 255, 128])
        for (span, expected) in [(red, [255, 0, 0, 255]), (halfBlue, [0, 0, 255, 128])] {
            let frame = try rasterizer.draw([try placed(span, from: SuitePoint(x: 10, y: 90), degrees: 0)],
                                            width: 100, height: 100)
            let alphas = stride(from: 3, to: frame.rgba.count, by: 4).map { frame.rgba[$0] }
            let full = try #require(alphas.firstIndex { abs(Int($0) - expected[3]) <= 1 }, "no fully covered pixel")
            let pixel = frame.rgba[(full * 4)..<(full * 4 + 4)].map(Int.init)
            for (got, want) in zip(pixel, expected) { #expect(abs(got - want) <= 2, "\(pixel) isn't \(expected)") }
        }
    }

    @Test func titleFrameFast() throws {
        let span = TextSpan("Forty graphemes on a title frame, drawn!", fontFamily: "Helvetica", fontSize: 72)
        let line = try placed(span, from: SuitePoint(x: 100, y: 540), degrees: 0)
        #expect(line.origins.count == 40)
        let start = ContinuousClock.now
        let frame = try rasterizer.draw([line], width: 1920, height: 1080)
        let elapsed = ContinuousClock.now - start
        #expect(frame.width == 1920 && frame.height == 1080)
        print("ShellTextDrawTests.titleFrameFast: 40 graphemes into 1920 x 1080 in \(elapsed)")
    }
}
#endif
