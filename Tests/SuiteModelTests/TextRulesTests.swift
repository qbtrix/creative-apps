// TextRulesTests.swift: shell-text ST-2, the checks for ST-3's `TextRules`
// written first and disabled by name until ST-3 turns them on: sizes inside
// 1...1,600, weights in hundreds, 4-byte colours, finite tracking, one origin
// and one angle per grapheme, and an empty family kept (the system font).
import SuiteModel
import Testing

@Suite(.disabled("ST-3 turns on TextRulesTests with TextRules")) struct TextRulesTests {
    @Test func sizeOutOfRangeRefused() {
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", fontSize: 0)) }
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", fontSize: 1_601)) }
    }

    @Test func sizeSixteenHundredAccepted() throws {
        #expect(try TextRules.validated(TextSpan("a", fontSize: 1_600)).fontSize == 1_600)
        #expect(try TextRules.validated(TextSpan("a", fontSize: 1)).fontSize == 1)
    }

    @Test func weightInHundreds() throws {
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", weight: 450)) }
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", weight: 1_000)) }
        #expect(try TextRules.validated(TextSpan("a", weight: 900)).weight == 900)
    }

    @Test func colourIsFourBytes() {
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", rgba: [0, 0, 0])) }
    }

    @Test func nanTrackingRefused() {
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", tracking: .nan)) }
    }

    @Test func emptyFamilyIsTheSystemFont() throws {
        #expect(try TextRules.validated(TextSpan("a", fontFamily: "")).fontFamily.isEmpty)
    }

    @Test func originsPerGrapheme() throws {
        let one = SuitePoint(x: 0, y: 0)
        let ok = PlacedSpan(span: TextSpan("é👋"), origins: [one, one], degrees: [0, 0])
        #expect(try TextRules.validated(ok) == ok)
        let short = PlacedSpan(span: TextSpan("é👋"), origins: [one], degrees: [0, 0])
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(short) }
        let nan = PlacedSpan(span: TextSpan("a"), origins: [one], degrees: [.nan])
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(nan) }
    }
}
