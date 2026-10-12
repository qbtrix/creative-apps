// NumericInputTests.swift: the parse-and-clamp rules behind the inspector's
// number fields. No SwiftUI here: NumericInput is plain Swift. macOS only.
import SuiteUI
import Testing

@Test func typedNumberAboveTheRangeClampsToItsTop() {
    #expect(NumericInput.parse("12", in: 0...10, keeping: 4) == 10)
}

@Test func typedNumberBelowTheRangeClampsToItsBottom() {
    #expect(NumericInput.parse("-7", in: 0...10, keeping: 4) == 0)
}

@Test func textThatIsNotANumberKeepsTheOldValue() {
    #expect(NumericInput.parse("abc", in: 0...10, keeping: 4) == 4)
    #expect(NumericInput.parse("", in: 0...10, keeping: 4) == 4)
}

@Test func nanKeepsTheOldValue() {
    #expect(NumericInput.parse("nan", in: 0...10, keeping: 4) == 4)
}

@Test func negativeFractionInsideTheRangeIsKept() {
    #expect(NumericInput.parse("-3.5", in: -5...5, keeping: 0) == -3.5)
}

@Test func surroundingWhitespaceIsIgnored() {
    #expect(NumericInput.parse("  7.25 ", in: 0...10, keeping: 4) == 7.25)
}

@Test func clampMovesValuesIntoTheRange() {
    #expect(NumericInput.clamp(11, to: 0...10) == 10)
    #expect(NumericInput.clamp(-1, to: 0...10) == 0)
    #expect(NumericInput.clamp(3, to: 0...10) == 3)
    #expect(NumericInput.clamp(.nan, to: 2...10) == 2)
}

@Test func formatRoundsToTwoDecimalsWithoutTrailingZeros() {
    #expect(NumericInput.format(12) == "12")
    #expect(NumericInput.format(0.5) == "0.5")
    #expect(NumericInput.format(1.239) == "1.24")
    #expect(NumericInput.format(-3.5) == "-3.5")
}

@Test func formattedTextParsesBack() {
    for value in [0, 12, 0.5, -3.5, 99.99] {
        #expect(NumericInput.parse(NumericInput.format(value), in: -100...100, keeping: 1) == value)
    }
}
