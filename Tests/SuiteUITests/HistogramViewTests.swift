// HistogramViewTests.swift: HistogramView's clipping reading (#3633), the
// accessibility value it speaks after the host's own. A pure static, no
// window. macOS only.
import SuiteModel
import SuiteUI
import Testing

@Test func histogramReadsItsClipping() {
    #expect(HistogramView.reading(.empty, empty: "No photo") == "No photo")
    let none = ToneHistogram(channels: [[1, 2]])
    #expect(HistogramView.reading(none, empty: "") == "No clipping")
    let both = ToneHistogram(channels: [[1, 2]], shadowClipped: 1, highlightClipped: 3)
    #expect(HistogramView.reading(both, empty: "") == "Shadows clipped, Highlights clipped")
}
