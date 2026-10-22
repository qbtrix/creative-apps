// FakeTextTests.swift: shell-text ST-6 (MJ-ST1), the fake's fixed advances:
// 0.5 em per grapheme plus tracking after each grapheme, ascent 0.8 em and
// descent 0.2 em, the numbers creative-core's `FixedAdvances` gives, so Linux
// layouts match core's. A span the rules refuse is refused here too.
import SuiteModel
import Testing

@Suite struct FakeTextTests {
    @Test(arguments: [10.0, 24, 72]) func matchesCoreNumbers(size: Double) throws {
        let m = try #require(try FakeText().measure([TextSpan("abc", fontSize: size)]).first)
        #expect(m.advances == Array(repeating: size * 0.5, count: 3))
        #expect(m.ascent == size * 0.8 && m.descent == size * 0.2)
    }

    @Test func trackingPerGrapheme() throws {
        let m = try #require(try FakeText().measure([TextSpan("abc", fontSize: 20, tracking: 2)]).first)
        #expect(m.advances == [12, 12, 12])
        let emoji = try #require(try FakeText().measure([TextSpan("a👋🏽", fontSize: 10, tracking: -1)]).first)
        #expect(emoji.advances == [4, 4])
    }

    @Test func trackingLeavesAscentAndDescent() throws {
        let m = try #require(try FakeText().measure([TextSpan("ab", fontSize: 10, tracking: 3)]).first)
        #expect(m.ascent == 8 && m.descent == 2)
    }

    @Test func eachSpanByItsOwnSize() throws {
        let spans = [TextSpan("ab", fontSize: 10), TextSpan("c", fontSize: 30, tracking: 1), TextSpan("", fontSize: 20)]
        let metrics = try FakeText().measure(spans)
        #expect(metrics.map(\.advances) == [[5, 5], [16], []])
        #expect(metrics.map(\.ascent) == [8, 24, 16])
    }

    @Test func refusesWhatTheRulesRefuse() {
        #expect(throws: SuiteError.self) { _ = try FakeText().measure([TextSpan("a"), TextSpan("b", fontSize: 0)]) }
        let short = PlacedSpan(span: TextSpan("ab"), origins: [SuitePoint(x: 0, y: 0)], degrees: [0])
        let text = FakeText()
        #expect(throws: SuiteError.self) { _ = try text.draw([short], width: 2, height: 2) }
        #expect(text.drawn.isEmpty)
    }
}
