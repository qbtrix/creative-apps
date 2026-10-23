// InspectorNoteTests.swift: SuiteUI's InspectorNote: it defaults to secondary
// help inset like the rows, keeps the identifier its caller passes, and with a
// value column starts at that x in the caller's named space. macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct InspectorNoteTests {
    @Test func itDefaultsToSecondaryHelpWithNoColumn() {
        let note = InspectorNote("Select a layer to edit its properties.")
        #expect(note.kind == .secondary)
        #expect(note.identifier == nil)
        #expect(note.column == nil)
        let error = InspectorNote("Unlock A to change it.", kind: .error, identifier: "halo.refusal")
        #expect(error.kind == .error && error.identifier == "halo.refusal")
    }

    @Test(arguments: [InspectorNote.Kind.secondary, .error]) func itWrapsToItsTextAtTheRowWidth(kind: InspectorNote.Kind) {
        let short = NSHostingView(rootView: InspectorNote("Short.", kind: kind).frame(width: 240))
        let long = NSHostingView(rootView: InspectorNote(String(repeating: "A long refusal. ", count: 12), kind: kind).frame(width: 240))
        #expect(short.fittingSize.height > 0)
        #expect(long.fittingSize.height > short.fittingSize.height, "a long note should wrap, not clip")
    }
}
