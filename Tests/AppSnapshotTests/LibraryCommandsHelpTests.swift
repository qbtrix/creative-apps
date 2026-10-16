// LibraryCommandsHelpTests.swift: Metadata > Auto Advance says what it does
// (#1665). XCUITest reads a menu item's help tag as no text, so the help is
// proven here. macOS only.
import Testing

@testable import LibraryApp

@Suite struct LibraryCommandsHelpTests {
    @Test func autoAdvanceHelpSaysItGoesToTheNextPhoto() {
        let help = LibraryCommands.autoAdvanceHelp(disabled: nil)
        #expect(help.contains("next photo"), "Auto Advance's help reads \(help)")
        #expect(help.contains("rating") && help.contains("flag"), "Auto Advance's help doesn't name what moves on: \(help)")
        #expect(!help.contains("label"), "a label never advances, yet the help names one: \(help)")
    }

    @Test func disabledAutoAdvanceHelpGivesTheReason() {
        let help = LibraryCommands.autoAdvanceHelp(disabled: "Open the Library window first.")
        #expect(help == "Auto Advance: Open the Library window first.")
    }
}
