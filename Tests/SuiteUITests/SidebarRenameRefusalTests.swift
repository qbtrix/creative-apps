// SidebarRenameRefusalTests.swift: a sidebar rename the app can refuse
// (lists-and-layers LL-6, #577). SidebarRenameField is the row's rename state:
// a refused commit keeps the draft as typed and sets the message, typing
// clears the message, an accepted commit closes the field, and Escape or focus
// lost while refused cancels and clears. The Void `onRename` forms of
// SidebarRow, SuiteSidebarList and SuiteWindow still rename and never refuse.
// macOS only.
import SwiftUI
import Testing
@testable import SuiteUI

@MainActor
@Suite struct SidebarRenameRefusalTests {
    private static let taken = "A layer named “Sky” already exists."

    /// Refuses "Sky" and records every name it is asked to take.
    @MainActor private final class Renamer {
        var asked: [String] = []
        func rename(_ name: String) -> String? {
            asked.append(name)
            return name == "Sky" ? SidebarRenameRefusalTests.taken : nil
        }
    }

    /// A field opened on `title` with `typed` in it.
    private func opened(_ title: String = "Layer 1", typed: String) -> SidebarRenameField {
        var field = SidebarRenameField()
        field.open(title)
        field.type(typed)
        return field
    }

    @Test func aRefusedCommitKeepsTheDraftAndSetsTheMessage() {
        let renamer = Renamer()
        var field = opened(typed: " Sky ")
        field.commit(original: "Layer 1", rename: renamer.rename)
        #expect(field.isOpen)
        #expect(field.draft == " Sky ", "the draft stays exactly as typed")
        #expect(field.message == Self.taken)
        #expect(renamer.asked == ["Sky"], "the app is asked with the trimmed name")
    }

    @Test func typingClearsTheMessage() {
        var field = opened(typed: "Sky")
        field.commit(original: "Layer 1", rename: Renamer().rename)
        #expect(field.message != nil)
        field.type("Sky 2")
        #expect(field.message == nil)
        #expect(field.draft == "Sky 2")
        #expect(field.isOpen)
    }

    @Test func anAcceptedCommitClosesTheField() {
        let renamer = Renamer()
        var field = opened(typed: "Ground")
        field.commit(original: "Layer 1", rename: renamer.rename)
        #expect(!field.isOpen)
        #expect(field.message == nil)
        #expect(renamer.asked == ["Ground"])
    }

    @Test func anUnchangedOrEmptyDraftClosesWithoutAsking() {
        let renamer = Renamer()
        for typed in ["Layer 1", "  ", ""] {
            var field = opened(typed: typed)
            field.commit(original: "Layer 1", rename: renamer.rename)
            #expect(!field.isOpen)
        }
        #expect(renamer.asked.isEmpty)
    }

    @Test func escapeCancelsAndClearsARefusal() {
        var field = opened(typed: "Sky")
        field.commit(original: "Layer 1", rename: Renamer().rename)
        field.cancel()
        #expect(!field.isOpen)
        #expect(field.message == nil)
    }

    @Test func focusLostWhileRefusedCancelsWithoutAskingAgain() {
        let renamer = Renamer()
        var field = opened(typed: "Sky")
        field.commit(original: "Layer 1", rename: renamer.rename)
        field.loseFocus(original: "Layer 1", rename: renamer.rename)
        #expect(!field.isOpen)
        #expect(field.message == nil)
        #expect(renamer.asked == ["Sky"], "no second refusal: focus loss drops the refused draft")
    }

    @Test func focusLostWithoutARefusalCommits() {
        let renamer = Renamer()
        var field = opened(typed: "Ground")
        field.loseFocus(original: "Layer 1", rename: renamer.rename)
        #expect(!field.isOpen)
        #expect(renamer.asked == ["Ground"])
    }

    @Test func theVoidFormStillRenamesAndNeverRefuses() throws {
        var names: [String] = []
        let rowForm = SidebarRow.refusable { names.append($0) }
        let lifted = try #require(rowForm)
        let refusal = lifted("Ground")
        #expect(refusal == nil)
        #expect(names == ["Ground"])
        #expect(SidebarRow.refusable(nil) == nil)

        var renamed: [String] = []
        let nodeForm = SidebarNode.refusable { id, name in renamed.append("\(id)=\(name)") }
        let node = try #require(nodeForm)
        let nodeRefusal = node("layer-1", "Ground")
        #expect(nodeRefusal == nil)
        #expect(renamed == ["layer-1=Ground"])
        #expect(SidebarNode.refusable(nil) == nil)

        var field = opened(typed: "Ground")
        field.commit(original: "Layer 1", rename: lifted)
        #expect(!field.isOpen)
        #expect(names == ["Ground", "Ground"])
    }

    /// Both rename forms compile on the row, the list and the window, so
    /// adding the refusable one broke no existing caller.
    @Test func bothRenameFormsBuild() {
        let item = SidebarItem(id: "a", title: "Layer 1", systemImage: "square")
        _ = SidebarRow(item, onRename: { (_: String) in })
        _ = SidebarRow(item, onRename: { (_: String) -> String? in Self.taken })
        _ = SidebarRow(item)
        let sections = [SidebarSection(id: "layers", title: "Layers", items: [item])]
        _ = SuiteSidebarList(
            sections: sections, selection: nil, onSelect: { _ in }, onRename: { (_: String, _: String) in })
        _ = SuiteSidebarList(
            sections: sections, selection: nil, onSelect: { _ in },
            onRename: { (_: String, _: String) -> String? in Self.taken })
        _ = SuiteWindow(
            title: "Doc", sections: sections, selection: nil, onSelect: { _ in },
            onRename: { (_: String, _: String) in }, content: { Text(verbatim: "Content") },
            inspector: { Text(verbatim: "Inspector") })
        _ = SuiteWindow(
            title: "Doc", sections: sections, selection: nil, onSelect: { _ in },
            onRename: { (_: String, _: String) -> String? in Self.taken }, content: { Text(verbatim: "Content") },
            inspector: { Text(verbatim: "Inspector") })
    }
}
