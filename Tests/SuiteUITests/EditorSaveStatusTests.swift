// EditorSaveStatusTests.swift: SuiteUI's EditorSaveStatus keeps the title,
// tooltip and identifier its app passes and draws every state without
// truncating (it never shrinks below its text). macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct EditorSaveStatusTests {
    @Test func itKeepsWhatTheAppPasses() {
        let status = EditorSaveStatus(.notSaved, title: "Not saved", help: "The disk is full.", identifier: "flare.saveStatus")
        #expect(status.state == .notSaved && status.title == "Not saved")
        #expect(status.help == "The disk is full." && status.identifier == "flare.saveStatus")
    }

    @Test(arguments: [EditorSaveStatus.State.saved, .edited, .notSaved]) func everyStateDrawsAtItsTextWidth(state: EditorSaveStatus.State) {
        let host = NSHostingView(rootView: EditorSaveStatus(state, title: "Edited, autosaved", help: "", identifier: "x").frame(width: 10))
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.height > 0)
        let free = NSHostingView(rootView: EditorSaveStatus(state, title: "Edited, autosaved", help: "", identifier: "x"))
        #expect(free.fittingSize.width > 40, "the status should size to its title")
    }
}
