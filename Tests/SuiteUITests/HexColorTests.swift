// HexColorTests.swift: the color rows' hex field (#718, IC-3). HexColorText,
// the suite's HexColorEditing, reads "#ff3b30", "FF3B30" and the "#F30"
// shorthand, refuses "zz", "#12345" and empty text, keeps the old color for
// text it refuses, and writes "#RRGGBB" upper case. HexColor reads through
// it. A hex commit ends its run once, even when it keeps the color; a run of
// color panel picks ends once when the panel closes.
// Mutating calls go into a local first: #expect can't call a mutating member.
// macOS only.
@testable import SuiteUI
import Testing

private let hex = HexColorText()

@Test func hexTextParsesLongShortAndEitherCase() {
    #expect(hex.parse("#ff3b30") == RGB8(0xFF, 0x3B, 0x30))
    #expect(hex.parse("FF3B30") == RGB8(0xFF, 0x3B, 0x30))
    #expect(hex.parse("#F30") == RGB8(0xFF, 0x33, 0x00))
    #expect(hex.parse("f30") == RGB8(0xFF, 0x33, 0x00))
    #expect(HexColor("#F30") == HexColor(0xFF, 0x33, 0x00))
}

@Test func hexTextRefusesWhatIsNotAColorAndKeepsTheOldOne() {
    for bad in ["zz", "#12345", "", "#", "##123456", "#GG0000", "#1234567"] {
        #expect(hex.parse(bad) == nil, "\(bad) read as a color")
        #expect(hex.committed(bad, old: RGB8(1, 2, 3)) == RGB8(1, 2, 3), "\(bad) changed the color")
    }
    #expect(hex.committed("#ff3b30", old: RGB8(1, 2, 3)) == RGB8(0xFF, 0x3B, 0x30))
}

@Test func hexTextFormatsUpperCaseWithHash() {
    #expect(hex.format(RGB8(0xFF, 0x3B, 0x30)) == "#FF3B30")
    #expect(hex.format(RGB8(1, 2, 0xAB)) == "#0102AB")
    #expect(HexColor(0x0a, 0xbc, 0xde).text == "#0ABCDE")
    #expect(hex.format(hex.committed("#f30", old: RGB8(0, 0, 0))) == "#FF3300")
}

@Test func aHexCommitEndsOnceAndSendsOnlyANewColor() {
    var ends = HexEnds()
    let typed = ends.committed("FF3B30", old: RGB8(0, 0, 0))
    #expect(typed.color == RGB8(0xFF, 0x3B, 0x30))
    #expect(typed.ended)
    #expect(ends.ends == 1)
    #expect(!ends.isOpen)

    let refused = ends.committed("zz", old: RGB8(1, 2, 3))
    #expect(refused.color == nil)
    #expect(refused.ended)
    let same = ends.committed("#010203", old: RGB8(1, 2, 3))
    #expect(same.color == nil)
    #expect(same.ended)
    #expect(ends.ends == 3)
}

@Test func panelPicksEndOnceWhenThePanelCloses() {
    var ends = HexEnds()
    let first = ends.picked()
    let second = ends.picked()
    #expect(first && !second)
    let closed = ends.closed()
    let again = ends.closed()
    #expect(closed && !again)
    #expect(ends.ends == 1)
    var idle = HexEnds()
    let nothing = idle.closed()
    #expect(!nothing)
    #expect(idle.ends == 0)
}
