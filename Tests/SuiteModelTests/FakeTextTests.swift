// FakeTextTests.swift: shell-text ST-2, the checks for ST-6's fixed advances
// written first and disabled by name until ST-6 turns them on: 0.5 em per
// grapheme plus tracking, ascent 0.8 em and descent 0.2 em, the numbers
// creative-core's `FixedAdvances` gives, so Linux layouts match core's.
import SuiteModel
import Testing

@Suite(.disabled("ST-6 turns on FakeTextTests with the fake's tracking")) struct FakeTextTests {
    @Test(arguments: [10.0, 24, 72]) func matchesCoreNumbers(size: Double) throws {
        let m = try #require(try FakeText().measure([TextSpan("abc", fontSize: size)]).first)
        #expect(m.advances == Array(repeating: size * 0.5, count: 3))
        #expect(m.ascent == size * 0.8 && m.descent == size * 0.2)
    }

    @Test func trackingPerGrapheme() throws {
        let m = try #require(try FakeText().measure([TextSpan("abc", fontSize: 20, tracking: 2)]).first)
        #expect(m.advances == [12, 12, 12])
    }
}
