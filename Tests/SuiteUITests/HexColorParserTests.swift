// HexColorParserTests.swift: the one hex parser every app's colour bridge
// goes through (adopt-suiteui-chrome AC-colour). HexColorText, and HexColor
// over it, read six digits and the three-digit shorthand, with or without one
// leading "#", in either case and with surrounding spaces; anything else is
// nil, and a commit of it keeps the old colour while still ending its run.
// The SuiteUI.HexColor mutation plan plants its bugs against these tests.
// macOS only (SuiteUI).
@testable import SuiteUI
import Testing

private let parser = HexColorText()

@Test func sixDigitsReadWithOrWithoutTheHash() {
    #expect(parser.parse("#1877F2") == RGB8(0x18, 0x77, 0xF2))
    #expect(parser.parse("1877F2") == RGB8(0x18, 0x77, 0xF2))
    #expect(parser.parse("#1877f2") == RGB8(0x18, 0x77, 0xF2))
    #expect(HexColor("1877F2") == HexColor(0x18, 0x77, 0xF2))
}

@Test func threeDigitsDoubleUpWithOrWithoutTheHash() {
    #expect(parser.parse("#F80") == RGB8(0xFF, 0x88, 0x00))
    #expect(parser.parse("f80") == RGB8(0xFF, 0x88, 0x00))
    #expect(HexColor("#0a0") == HexColor(0x00, 0xAA, 0x00))
}

@Test func surroundingSpacesAreIgnored() {
    #expect(parser.parse("  #1877F2 ") == RGB8(0x18, 0x77, 0xF2))
}

@Test func whatIsNotAHexColorIsNil() {
    let invalid = ["", "#", "##1877F2", "#12345", "1234567", "#GG0000", "+12345", "-12345", "#+1234", "F8", "#F8"]
    for text in invalid {
        #expect(parser.parse(text) == nil, "\(text) read as a colour")
        #expect(HexColor(text) == nil, "\(text) read as a HexColor")
    }
}

@Test func formatWritesSixUpperCaseDigitsAfterAHash() {
    #expect(parser.format(RGB8(0x18, 0x77, 0xF2)) == "#1877F2")
    #expect(parser.format(RGB8(0, 0x0A, 0xFF)) == "#000AFF")
    #expect(HexColor(parser.parse("f80") ?? RGB8(0, 0, 0)).text == "#FF8800")
}

@Test func aRefusedCommitKeepsTheOldColourAndStillEndsItsRun() {
    var ends = HexEnds()
    let refused = ends.committed("zz", old: RGB8(1, 2, 3))
    #expect(refused.color == nil)
    #expect(refused.ended)
    #expect(ends.ends == 1)
    #expect(parser.committed("zz", old: RGB8(1, 2, 3)) == RGB8(1, 2, 3))
    let taken = ends.committed("#F80", old: RGB8(1, 2, 3))
    #expect(taken.color == RGB8(0xFF, 0x88, 0x00))
    #expect(taken.ended)
    #expect(ends.ends == 2)
    #expect(!ends.isOpen)
}
