// HistogramViewAccessTests.swift: what a UI test reads off HistogramView's one
// accessibility element (#3560). XCUITest reads SwiftUI accessibility values
// as empty strings (#262), so Library's journey read the label, "Histogram",
// and never saw the mean. With a host value the label carries the readout
// (the value, then the clipping reading); without one it stays "Histogram".
import SuiteModel
@testable import SuiteUI
import Testing

@Suite struct HistogramViewAccessTests {
    private let clipped = ToneHistogram(heights: [0.2, 0.5, 1], clipsShadows: false, clipsHighlights: true)

    @Test func aHostValueTravelsInTheLabel() {
        #expect(HistogramView.label(clipped, value: "mean 0.4213", empty: "Rendering the photo…")
            == "mean 0.4213  ·  Highlights clipped")
        #expect(HistogramView.label(.empty, value: "mean 0.4213", empty: "Rendering the photo…")
            == "mean 0.4213  ·  Rendering the photo…")
    }

    @Test func withoutAHostValueTheLabelIsHistogram() {
        #expect(HistogramView.label(clipped, value: nil, empty: "No histogram") == "Histogram")
    }
}
