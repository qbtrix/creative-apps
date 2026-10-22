// TextContractTests.swift: shell-text ST-1 (MJ-ST0). `SuiteServices.fake().text`
// measures "Hi 👋" as 4 advances, lists its families by name, draws a clear
// frame and records the spans; an unavailable fake throws its reason, and
// `pending["text"]` names why the text service isn't live.
import SuiteModel
import Testing

@Suite struct TextContractTests {
    @Test func emojiIsOneAdvance() throws {
        let span = TextSpan("Hi 👋", fontFamily: FakeText.systemFamily, fontSize: 20)
        let metrics = try SuiteServices.fake().text.measure([span])
        #expect(metrics.count == 1)
        #expect(metrics.first?.advances == [10, 10, 10, 10])
        #expect(metrics.first?.ascent == 16 && metrics.first?.descent == 4)
        #expect(metrics.first?.resolvedFamily == FakeText.systemFamily)
    }

    @Test func oneMetricsPerSpanAndUnknownFamiliesFallBack() throws {
        let spans = [TextSpan("ab", fontFamily: "Serif", fontSize: 10), TextSpan("c", fontFamily: "Nowhere", fontSize: 40)]
        let metrics = try FakeText().measure(spans)
        #expect(metrics.map(\.advances) == [[5, 5], [20]])
        #expect(metrics.map(\.resolvedFamily) == ["Serif", FakeText.systemFamily])
    }

    @Test func familiesAreSortedWithFaces() {
        let families = FakeText().families()
        #expect(families.count == 3)
        #expect(families.map(\.name) == families.map(\.name).sorted())
        #expect(families.map(\.id) == families.map(\.name))
        let system = families.first { $0.name == FakeText.systemFamily }
        #expect(system?.faces.contains(FontFace(name: "Regular", weight: 400, italic: false)) == true)
        #expect(system?.faces.contains { $0.weight == 700 } == true)
    }

    @Test func drawReturnsAClearFrameAndRecordsTheSpans() throws {
        let text = FakeText()
        let placed = PlacedSpan(span: TextSpan("Hi"), origins: [SuitePoint(x: 0, y: 1), SuitePoint(x: 2, y: 1)],
                                degrees: [0, 45])
        let frame = try text.draw([placed], width: 4, height: 2)
        #expect(frame.width == 4 && frame.height == 2)
        #expect(frame.rgba == Array(repeating: 0, count: 32))
        #expect(text.drawn == [placed])
        #expect(throws: SuiteError.self) { _ = try text.draw([placed], width: 0, height: 2) }
        #expect(throws: SuiteError.self) { _ = try text.draw([placed], width: Int.max, height: 2) }
    }

    @Test func unavailableThrowsItsReason() {
        let reason = "Text measuring and drawing isn't available yet."
        let text = FakeText(unavailable: reason)
        #expect(throws: SuiteError.notAvailable(reason)) { _ = try text.measure([TextSpan("a")]) }
        #expect(throws: SuiteError.notAvailable(reason)) { _ = try text.draw([], width: 1, height: 1) }
        #expect(text.families().isEmpty)
    }

    @Test func pendingNamesText() {
        let s = SuiteServices.fake()
        #expect(s.text is FakeText)
        #expect(s.pending["text"] == "Text measuring and drawing isn't available yet.")
        #expect(s.pending["text"] == SuiteServices.notConnected("text"))
        #expect(SuiteServices.slotFeatures["text"] == "shell-text")
    }

    @Test func spanDefaultsAndValuesCompare() {
        let span = TextSpan("a")
        #expect(span.fontFamily.isEmpty && span.fontSize == 12 && span.weight == 400)
        #expect(!span.italic && span.rgba == [0, 0, 0, 255] && span.tracking == 0)
        #expect(SpanMetrics(advances: [1], ascent: 2, descent: 3, resolvedFamily: "x").ascent == 2)
        #expect(SuitePoint(x: 1, y: 2) != SuitePoint(x: 2, y: 1))
        #expect(TextRules.sizes == 1...1_600 && TextRules.maxGraphemes == 100_000)
    }
}
