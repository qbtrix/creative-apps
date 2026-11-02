// DesignJourneyTests+TextStyle.swift (text-style TS-3, DJ-TS): Design's
// paragraph style journey. Select a text box, pick a family in the font
// picker, set Italic, Justify, Line Height 1.5 and Letter Spacing 20; the
// canvas reflows, a family change refits the box, and Undo steps back one
// control at a time. Skipped by name until TS-8 draws the new fields and
// routes the shared text style rows (`suite.text.*`) to Design's commands;
// TS-3 only shows the rows, disabled with "Text styles aren't connected in this window yet.".
import XCTest

final class DesignTextStyleJourneyTests: XCTestCase {
    @MainActor func testParagraphStyle() throws {
        throw XCTSkip("DJ-TS waits on TS-8: the text style rows show in Design's inspector but don't act yet")
    }
}
