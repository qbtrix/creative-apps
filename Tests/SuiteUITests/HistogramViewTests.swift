// HistogramViewTests.swift: HistogramView's clipping reading (#3633), the
// accessibility value it speaks after the host's own, and its corner markers,
// which an empty well leaves off. Pure statics, no window. macOS only.
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

/// An empty well draws no clipping corners: with no bins there is nothing to clip.
@Test func emptyHistogramDrawsNoClipMarkers() {
    #expect(HistogramView.clipMarkers(.empty).isEmpty)
    let none = ToneHistogram(channels: [[1, 2]])
    #expect(HistogramView.clipMarkers(none) == [false, false])
    let shadows = ToneHistogram(channels: [[1, 2]], shadowClipped: 1)
    #expect(HistogramView.clipMarkers(shadows) == [true, false])
}
