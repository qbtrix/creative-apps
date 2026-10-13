// StudioScrubRowTests.swift: how far a Studio row's fill reaches. macOS only.
import SuiteUI
import Testing

@Test func fillFractionClampsToRange() {
    #expect(StudioScrubRow.fillFraction(0.5, in: -1...2) == 0.5)
    #expect(StudioScrubRow.fillFraction(0.25, in: 0...1) == 0.25)
    #expect(StudioScrubRow.fillFraction(-4, in: 0...1) == 0)
    #expect(StudioScrubRow.fillFraction(9, in: 0...1) == 1)
    #expect(StudioScrubRow.fillFraction(.nan, in: 0...1) == 0)
    #expect(StudioScrubRow.fillFraction(1, in: 1...1) == 0)
}

@Test func valueShowsTwoDecimals() {
    #expect(StudioScrubRow.valueText(0.25) == "0.25")
    #expect(StudioScrubRow.valueText(1) == "1.00")
    #expect(StudioScrubRow.valueText(-0.3) == "-0.30")
}
