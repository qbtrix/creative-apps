// HaloTextAdapterTests.swift (#5280): HaloTextAdapter puts Halo's TextRasterizing on a suite TextServices, so a host
// holding the shared service (LiveText on a Mac) draws Halo text through it. A recording fake stands in for the
// service: every grapheme advances half an em, the line is 0.75 em up and 0.2 em down, and draw fills the frame with
// the span's colour. The tests pin the box, the placement on its baseline, the span it sends and the decoding to linear light.
import CoreRaster
@testable import HaloModel
import SuiteModel
import Testing

/// Measures half an em a grapheme, 0.75 em ascent, 0.2 em descent; draws a frame of the span's colour; keeps what it saw.
private final class RecordingText: TextServices, @unchecked Sendable {
    var measured: [TextSpan] = [], drawn: [PlacedSpan] = [], sizes: [(Int, Int)] = []
    var refuse = false

    func measure(_ spans: [TextSpan]) throws(SuiteError) -> [SpanMetrics] {
        if refuse { throw .notAvailable("no") }
        measured += spans
        return spans.map { span in
            SpanMetrics(advances: span.string.map { _ in span.fontSize / 2 }, ascent: span.fontSize * 0.75,
                        descent: span.fontSize * 0.2, resolvedFamily: FakeText.systemFamily)
        }
    }

    func families() -> [FontFamily] { [] }

    func draw(_ spans: [PlacedSpan], width: Int, height: Int) throws(SuiteError) -> MediaFrame {
        drawn += spans; sizes.append((width, height))
        let rgba = spans.first?.span.rgba ?? [0, 0, 0, 0]
        return try MediaFrame(width: width, height: height, rgba: Array((0..<width * height).map { _ in rgba }.joined()))
    }
}

@Suite struct HaloTextAdapterTests {
    @Test func theBoxIsTheAdvancesByAscentPlusDescentRoundedUp() {
        // "abc" at 9 pt: 13.5 wide, 6.75 + 1.8 = 8.55 tall.
        let box = HaloTextAdapter(RecordingText()).measure(HaloTextContent(string: "abc", fontSize: 9))
        #expect(box == HaloLayerRect(x: 0, y: 0, width: 14, height: 9))
    }

    @Test func eachGraphemeSitsAfterTheOnesBeforeItOnTheBaseline() throws {
        let text = RecordingText()
        // 10 pt: 5 a grapheme, box 15 by 10 (7.5 + 2 = 9.5 up), baseline 10 - 2 = 8 from the top.
        _ = try HaloTextAdapter(text).rasterize(HaloTextContent(string: "Hi!", fontSize: 10), color: .init(red: 1, green: 0, blue: 0))
        let placed = try #require(text.drawn.first)
        #expect(placed.origins == [SuitePoint(x: 0, y: 8), SuitePoint(x: 5, y: 8), SuitePoint(x: 10, y: 8)])
        #expect(placed.degrees == [0, 0, 0])
        #expect(text.sizes.first?.0 == 15 && text.sizes.first?.1 == 10)
    }

    @Test func theSpanIsOneLineInTheSystemFamilyAndTheLayersColour() throws {
        let text = RecordingText()
        _ = try HaloTextAdapter(text).rasterize(HaloTextContent(string: "a\nb", fontSize: 5_000),
                                                color: .init(red: 1, green: 0.5, blue: .nan))
        let span = try #require(text.drawn.first?.span)
        #expect(span.string == "a b")
        #expect(span.fontFamily == "")
        #expect(span.fontSize == TextRules.sizes.upperBound)
        #expect(span.rgba == [255, 128, 0, 255])
    }

    @Test func thePixelsAreLinearLightAtTheBoxsSize() throws {
        // sRGB 0.5 (byte 128) is about 0.216 in linear light.
        let buffer = try HaloTextAdapter(RecordingText()).rasterize(HaloTextContent(string: "Hi", fontSize: 20),
                                                                    color: .init(red: 0.5, green: 1, blue: 0))
        #expect(buffer.width == 20 && buffer.height == 19)
        let pixel = try buffer.pixel(x: 3, y: 3)
        #expect(abs(pixel.r - 0.216) < 0.01 && pixel.g == 1 && pixel.b == 0 && pixel.a == 1)
    }

    @Test func aRefusedMeasureIsAOnePixelBoxAndRasterizeThrows() {
        let text = RecordingText()
        text.refuse = true
        let adapter = HaloTextAdapter(text)
        #expect(adapter.measure(HaloTextContent(string: "x", fontSize: 12)) == HaloLayerRect(x: 0, y: 0, width: 1, height: 1))
        #expect(throws: SuiteError.self) { try adapter.rasterize(HaloTextContent(string: "x"), color: .init(red: 0, green: 0, blue: 0)) }
    }
}
