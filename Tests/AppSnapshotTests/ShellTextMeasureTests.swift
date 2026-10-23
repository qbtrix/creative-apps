// ShellTextMeasureTests.swift: shell-text ST-4 (MJ-ST2, packet
// suite/features/shell-text.md). CoreTextMeasurer gives one advance per
// grapheme: "office" in a font with an "ffi" ligature is 6 advances that sum
// to the line's width, the ligature's advance split evenly over its three
// graphemes; "👋🏽" is one grapheme with one advance; ascent and descent are
// the font's. An unknown family falls back to the system font and says so;
// tracking adds once per grapheme. paragraphFast reports its time (Mac
// finisher), it asserts no budget. macOS only.
#if os(macOS)
import CoreText
import Foundation
import SuiteModel
import SuiteShell
import Testing

@Suite(.timeLimit(.minutes(1))) struct ShellTextMeasureTests {
    let measurer = CoreTextMeasurer()

    private func one(_ span: TextSpan) throws -> SpanMetrics {
        let all = try measurer.measure([span])
        return try #require(all.first)
    }

    /// A Mac family that sets "office" with fewer glyphs than characters (an "ffi" ligature).
    private func ligatureFamily(size: Double) -> String? {
        ["Hoefler Text", "Baskerville", "Didot", "Palatino", "Times New Roman"].first { family in
            let font = CTFontCreateWithName(family as CFString, size, nil)
            let attributes = [kCTFontAttributeName: font] as CFDictionary
            guard CTFontCopyFamilyName(font) as String == family,
                  let string = CFAttributedStringCreate(nil, "office" as CFString, attributes) else { return false }
            return CTLineGetGlyphCount(CTLineCreateWithAttributedString(string)) < 6
        }
    }

    /// The width Core Text gives `text` in `family` at `size`.
    private func lineWidth(_ text: String, family: String, size: Double) throws -> Double {
        let font = CTFontCreateWithName(family as CFString, size, nil)
        let attributes = [kCTFontAttributeName: font] as CFDictionary
        let string = try #require(CFAttributedStringCreate(nil, text as CFString, attributes))
        return CTLineGetTypographicBounds(CTLineCreateWithAttributedString(string), nil, nil, nil)
    }

    @Test func ligatureIsSixAdvancesSummingToTheLine() throws {
        let family = try #require(ligatureFamily(size: 40), "no ffi ligature font on this Mac")
        let m = try one(TextSpan("office", fontFamily: family, fontSize: 40))
        try #require(m.advances.count == 6)
        #expect(m.resolvedFamily == family)
        let total = m.advances.reduce(0, +)
        #expect(abs(total - (try lineWidth("office", family: family, size: 40))) < 0.01)
        // f, f and i share the one ligature glyph's advance evenly.
        #expect(abs(m.advances[1] - m.advances[2]) < 0.001 && abs(m.advances[2] - m.advances[3]) < 0.001)
        #expect(m.advances.allSatisfy { $0 > 0 })
    }

    @Test func emojiWithSkinToneIsOneAdvance() throws {
        let m = try one(TextSpan("👋🏽", fontSize: 30))
        #expect(m.advances.count == 1)
        #expect((m.advances.first ?? 0) > 0)
        let mixed = try one(TextSpan("Hi 👋", fontSize: 30))
        #expect(mixed.advances.count == 4)
        #expect(mixed.advances.allSatisfy { $0 > 0 })
    }

    @Test func ascentAndDescentAreTheFonts() throws {
        let font = CTFontCreateWithName("Helvetica" as CFString, 20, nil)
        let m = try one(TextSpan("Hamburg", fontFamily: "Helvetica", fontSize: 20))
        #expect(abs(m.ascent - CTFontGetAscent(font)) < 0.01)
        #expect(abs(m.descent - CTFontGetDescent(font)) < 0.01)
        #expect(m.resolvedFamily == "Helvetica")
    }

    @Test func unknownFamilyFallsBack() throws {
        let unknown = try one(TextSpan("Hello", fontFamily: "No Such Family 7Q", fontSize: 18))
        let system = try one(TextSpan("Hello", fontSize: 18))
        #expect(unknown.resolvedFamily == FakeText.systemFamily)
        #expect(system.resolvedFamily == FakeText.systemFamily)
        #expect(unknown.advances == system.advances)
        #expect(unknown.ascent > 0 && unknown.descent > 0)
    }

    @Test func boldIsWiderThanRegular() throws {
        let regular = try one(TextSpan("Wombat", fontFamily: "Helvetica", fontSize: 24, weight: 400))
        let bold = try one(TextSpan("Wombat", fontFamily: "Helvetica", fontSize: 24, weight: 700))
        #expect(bold.advances.reduce(0, +) > regular.advances.reduce(0, +))
    }

    @Test func trackingAddsOncePerGrapheme() throws {
        let plain = try one(TextSpan("ab👋🏽", fontFamily: "Helvetica", fontSize: 16))
        let tracked = try one(TextSpan("ab👋🏽", fontFamily: "Helvetica", fontSize: 16, tracking: 3))
        #expect(tracked.advances.count == 3)
        for (a, b) in zip(plain.advances, tracked.advances) { #expect(abs(b - a - 3) < 0.001) }
    }

    @Test func oneMetricsPerSpanAndEmptyIsNoAdvances() throws {
        let spans = [TextSpan("ab", fontSize: 12), TextSpan("", fontSize: 12), TextSpan("é", fontSize: 12)]
        let all = try measurer.measure(spans)
        #expect(all.map(\.advances.count) == [2, 0, 1])
        #expect(all.allSatisfy { $0.ascent > 0 && $0.descent > 0 })
    }

    @Test func paragraphFast() throws {
        let words = String(repeating: "office hours 👋 ", count: 50)
        let spans = [TextSpan(words, fontSize: 14), TextSpan(words, fontFamily: "Helvetica", fontSize: 14, weight: 700),
                     TextSpan(words, fontFamily: "Helvetica", fontSize: 14, italic: true)]
        let start = ContinuousClock.now
        let all = try measurer.measure(spans)
        let elapsed = ContinuousClock.now - start
        #expect(all.map(\.advances.count) == spans.map(\.string.count))
        print("ShellTextMeasureTests.paragraphFast: \(spans.map(\.string.count).reduce(0, +)) graphemes in \(elapsed)")
    }
}
#endif
