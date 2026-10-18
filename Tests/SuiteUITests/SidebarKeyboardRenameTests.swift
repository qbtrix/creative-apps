// SidebarKeyboardRenameTests.swift: a sidebar rename from the keyboard and
// from VoiceOver (lists-and-layers LL-7, #108). Return on the focused row and
// the "Rename" accessibility action open the rename field only on a row with
// `onRename`, never while it is already renaming; the double-click still
// renames from the title alone (SidebarRenameGestureTests). The view wiring is
// read from SidebarRow.swift, as SidebarRenameGestureTests does. macOS only.
import Foundation
import Testing
@testable import SuiteUI

/// SidebarRow.swift's source with comments and whitespace removed: this file
/// is Tests/SuiteUITests/<name>.swift, so the package root is three levels up.
private func squeezedSidebarRow(from file: String = #filePath) throws -> String {
    let root = URL(fileURLWithPath: file).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let text = try String(contentsOf: root.appending(path: "Sources/SuiteUI/SidebarRow.swift"), encoding: .utf8)
    return String(
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in line.range(of: "//").map { line[..<$0.lowerBound] } ?? line }
            .joined(separator: "\n")
            .filter { !$0.isWhitespace })
}

@Suite struct SidebarKeyboardRenameTests {
    @Test func returnRenamesOnlyARenamableRowThatIsNotRenaming() {
        #expect(SidebarRow.keyRenames(renamable: true, renaming: false))
        #expect(!SidebarRow.keyRenames(renamable: false, renaming: false), "Return renamed a row without onRename")
        #expect(!SidebarRow.keyRenames(renamable: true, renaming: true), "Return reopened a field already open")
        #expect(!SidebarRow.keyRenames(renamable: false, renaming: true))
    }

    @Test func theRowHandlesReturnThroughTheRenameCheck() throws {
        let source = try squeezedSidebarRow()
        #expect(source.contains(".onKeyPress(.return){requestRename()}"), "Return on the focused row doesn't rename")
        #expect(
            source.contains(
                "privatefuncrequestRename()->KeyPress.Result{"
                    + "guardSelf.keyRenames(renamable:onRename!=nil,renaming:field.isOpen)else{return.ignored}"
                    + "beginRename(on:.title)return.handled}"),
            "Return must pass on (.ignored) for a row without onRename and open the field otherwise")
    }

    @Test func aRenamableRowExposesARenameAction() throws {
        #expect(SidebarRow.renameActionName == "Rename")
        let source = try squeezedSidebarRow()
        #expect(
            source.contains(
                ".accessibilityActions{ifonRename!=nil{Button(Self.renameActionName){_=requestRename()}}}"),
            "the Rename accessibility action is missing, or listed on a row without onRename")
    }

    @Test func aDoubleClickOnAToggleOrBlankSpaceStillNeverRenames() {
        #expect(!SidebarRow.doubleClickRenames(.toggle, renamable: true, renaming: false))
        #expect(!SidebarRow.doubleClickRenames(.blank, renamable: true, renaming: false))
        #expect(SidebarRow.doubleClickRenames(.title, renamable: true, renaming: false))
    }
}
