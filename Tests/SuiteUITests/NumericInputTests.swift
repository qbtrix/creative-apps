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

@Test func closingWithoutAnEditKeepsTheUnroundedValue() {
    let gamma = 1.2345253
    #expect(NumericInput.committed(NumericInput.format(gamma), in: 0.1...9.99, keeping: gamma, edited: false) == gamma)
    #expect(NumericInput.committed(" 1.23 ", in: 0.1...9.99, keeping: gamma, edited: false) == gamma)
    #expect(NumericInput.committed("-12.35", in: -100...100, keeping: -12.345, edited: false) == -12.345)
}

@Test func typingTheOpeningTextCommitsIt() {
    // #526: a number typed over the field's opening text is a deliberate edit.
    let white = Double(Float(0.996))
    #expect(NumericInput.committed(NumericInput.format(white), in: 0...1, keeping: white, edited: true) == 1)
    let black = Double(Float(0.004))
    #expect(NumericInput.committed(NumericInput.format(black), in: 0...1, keeping: black, edited: true) == 0)
    #expect(NumericInput.committed("1.23", in: 0.1...9.99, keeping: 1.2345, edited: true) == 1.23)
    #expect(NumericInput.committed(" 1.23 ", in: 0.1...9.99, keeping: 1.2345, edited: true) == 1.23)
}

@Test func theSameNumberCommitsWhateverItsSpelling() {
    let white = Double(Float(0.996))
    for text in ["1", "1.0", "1.00", " 1 "] {
        #expect(NumericInput.committed(text, in: 0...1, keeping: white, edited: true) == 1)
    }
}

@Test func typingANewNumberStillCommitsIt() {
    #expect(NumericInput.committed("1.2", in: 0.1...9.99, keeping: 1.2345, edited: true) == 1.2)
    #expect(NumericInput.committed("60.391", in: 0...100, keeping: 60.39, edited: true) == 60.391)
    #expect(NumericInput.committed("200", in: 0...100, keeping: 60.39, edited: true) == 100)
}

@Test func emptyOrInvalidTypedTextKeepsTheOldValue() {
    for text in ["", "   ", "abc", "nan", "1.2.3", "-"] {
        #expect(NumericInput.committed(text, in: 0...100, keeping: 60.39, edited: true) == 60.39)
    }
}
