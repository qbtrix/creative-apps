// TextRulesTests.swift: shell-text ST-3 (MJ-ST1), the checks for `TextRules`:
// sizes inside 1...1,600, weights in hundreds, 4-byte colours, finite
// tracking, at most `maxGraphemes`, one finite origin and one finite angle per
// grapheme, and an empty or unknown family kept (it falls back when measured).
import SuiteModel
import Testing

@Suite struct TextRulesTests {
    @Test func sizeOutOfRangeRefused() {
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", fontSize: 0)) }
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", fontSize: 1_601)) }
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", fontSize: .nan)) }
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", fontSize: .infinity)) }
    }

    @Test func sizeSixteenHundredAccepted() throws {
        #expect(try TextRules.validated(TextSpan("a", fontSize: 1_600)).fontSize == 1_600)
        #expect(try TextRules.validated(TextSpan("a", fontSize: 1)).fontSize == 1)
    }

    @Test func weightInHundreds() throws {
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", weight: 450)) }
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", weight: 1_000)) }
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", weight: 0)) }
        #expect(try TextRules.validated(TextSpan("a", weight: 900)).weight == 900)
        #expect(try TextRules.validated(TextSpan("a", weight: 100)).weight == 100)
    }

    @Test func colourIsFourBytes() {
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", rgba: [0, 0, 0])) }
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", rgba: [0, 0, 0, 0, 0])) }
    }

    @Test func nanTrackingRefused() throws {
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", tracking: .nan)) }
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan("a", tracking: -.infinity)) }
        #expect(try TextRules.validated(TextSpan("a", tracking: -2)).tracking == -2)
    }

    @Test func graphemeLimit() throws {
        let most = String(repeating: "👋🏽", count: TextRules.maxGraphemes)
        #expect(try TextRules.validated(TextSpan(most)).string == most)
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(TextSpan(most + "a")) }
    }

    @Test func emptyFamilyIsTheSystemFont() throws {
        #expect(try TextRules.validated(TextSpan("a", fontFamily: "")).fontFamily.isEmpty)
        #expect(try TextRules.validated(TextSpan("a", fontFamily: "Nowhere")).fontFamily == "Nowhere")
    }

    @Test func validSpanUnchanged() throws {
        let span = TextSpan("Hi", fontFamily: "Serif", fontSize: 18, weight: 700, italic: true, rgba: [1, 2, 3, 4],
                            tracking: 1.5)
        #expect(try TextRules.validated(span) == span)
    }

    @Test func originsPerGrapheme() throws {
        let one = SuitePoint(x: 0, y: 0)
        let ok = PlacedSpan(span: TextSpan("é👋"), origins: [one, one], degrees: [0, 0])
        #expect(try TextRules.validated(ok) == ok)
        let short = PlacedSpan(span: TextSpan("é👋"), origins: [one], degrees: [0, 0])
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(short) }
        let nan = PlacedSpan(span: TextSpan("a"), origins: [one], degrees: [.nan])
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(nan) }
        let fewAngles = PlacedSpan(span: TextSpan("é👋"), origins: [one, one], degrees: [0])
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(fewAngles) }
        let far = PlacedSpan(span: TextSpan("a"), origins: [SuitePoint(x: .infinity, y: 0)], degrees: [0])
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(far) }
        let badSpan = PlacedSpan(span: TextSpan("a", fontSize: 0), origins: [one], degrees: [0])
        #expect(throws: SuiteError.self) { _ = try TextRules.validated(badSpan) }
    }
}
