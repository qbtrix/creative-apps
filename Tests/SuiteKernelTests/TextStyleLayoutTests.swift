// TextStyleLayoutTests.swift (text-style TS-1 written, TS-5 turns on): `TextStyleRules.layout` over FlareCore's
// `TextLayout` with fixed advances (every grapheme 10 pt, ascent 8, descent 2): line height sets the baseline gap,
// tracking in thousandths of an em widens a line, and justify spans the box on every line but a paragraph's last.
// Disabled by name until TS-5 builds the body.
import Testing
import SuiteKernel

@Suite struct TextStyleLayoutTests {
    /// The test's measurer: 10 pt per grapheme, ascent 8 and descent 2, whatever the font.
    static func fixed(_ graphemes: [String]) -> (advances: [Double], ascent: Double, descent: Double) {
        (Array(repeating: 10, count: graphemes.count), 8, 2)
    }
    /// The standard style with `edit` applied to its paragraph.
    static func style(_ edit: (inout ParagraphStyle) -> Void) -> TextStyle {
        var style = TextStyle.standard
        edit(&style.paragraph)
        return style
    }

    @Test(.disabled("waits on TS-5")) func lineHeightSetsTheBaselineGap() throws {
        let layout = try TextStyleRules.layout("one\ntwo", style: Self.style { $0.lineHeight = 1.5 }, advances: Self.fixed)
        try #require(layout.lines.count == 2)
        #expect(abs(layout.lines[1].baseline - layout.lines[0].baseline - 1.5 * (8 + 2)) < 1e-9)
    }
    @Test(.disabled("waits on TS-5")) func trackingIsThousandthsOfAnEm() throws {
        let plain = try TextStyleRules.layout("abcdefghij", style: .standard, advances: Self.fixed)
        let tracked = try TextStyleRules.layout("abcdefghij", style: Self.style { $0.tracking = 100 }, advances: Self.fixed)
        let (a, b) = (try #require(plain.lines.first), try #require(tracked.lines.first))
        #expect(abs(a.width - 100) < 1e-9)
        #expect(abs(b.width - a.width - TextStyle.standard.size) < 1e-9)  // 10 graphemes × 0.1 em = 1 em
    }
    @Test(.disabled("waits on TS-5")) func justifySpansTheBoxButNotTheLastLine() throws {
        let style = Self.style { $0.alignment = .justified; $0.boxWidth = 100 }
        let layout = try TextStyleRules.layout("aa bb cc dd ee ff", style: style, advances: Self.fixed)
        try #require(layout.lines.count == 2)
        let last = try #require(layout.lines.last)
        #expect(abs(layout.lines[0].width - 100) < 1e-9)
        #expect(last.width < 100 - 1)
        #expect(last.x.first == 0)
    }
    @Test(.disabled("waits on TS-5")) func eachGraphemeIsMeasured() throws {
        let layout = try TextStyleRules.layout("héllo👋🏽", style: .standard, advances: Self.fixed)
        let line = try #require(layout.lines.first)
        #expect(line.graphemes == 0..<6 && abs(line.width - 60) < 1e-9)
    }
}
