// UnsavedPromptTests.swift: the one unsaved-changes alert every app shows
// (files-history FH-a, #2939): its message names the document, its
// informative text, Save / Don't Save / Cancel in order, and the save
// indicator's word from the session. Linux and macOS.
import Foundation
import Testing
import SuiteKernel

@Suite struct UnsavedPromptTests {
    @Test func theMessageNamesTheDocument() {
        #expect(UnsavedPrompt.message(for: "Poster.design")
            == "Do you want to save the changes made to the document \u{201C}Poster.design\u{201D}?")
        #expect(UnsavedPrompt.informativeText == "Your changes will be lost if you don't save them.")
    }

    @Test func theButtonsAreSaveDontSaveCancel() {
        #expect(UnsavedPrompt.answers == [.save, .dontSave, .cancel])
        #expect(UnsavedPrompt.answers.map(UnsavedPrompt.title(of:)) == ["Save", "Don't Save", "Cancel"])
        #expect([0, 1, 2, 3, -1].map(UnsavedPrompt.answer(forButton:)) == [.save, .dontSave, .cancel, .cancel, .cancel])
    }

    @Test func theStateTextReadsSavedEditedOrNotSaved() {
        var session = DocumentSession(token: 0, status: .saved)
        #expect(session.stateText == "Saved")
        session.didEdit(token: 1, at: Date(timeIntervalSince1970: 1))
        #expect(session.stateText == "Edited")
        session.status = .failed("disk full")
        #expect(session.stateText == "Not saved")
        session.status = .saved
        session.didEdit(token: 0, at: Date(timeIntervalSince1970: 2))
        #expect(session.stateText == "Saved")
    }
}
