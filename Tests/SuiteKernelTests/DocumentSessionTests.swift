// DocumentSessionTests.swift: the document session's checks (editor-kernel EK-23, slice EK-doc).
// Dirty is read from the saved and current tokens (so undoing back to the
// saved step reads clean), a save names the status, autosave is due a delay
// after the last edit that no autosave has covered, and the recovery offer
// asks a question that names the document. Written first (EK-23), turned on
// by EK-24 with the bodies (docs/factory/lead.md rule 13). KJ8, the session
// walk, closes the file.
import Foundation
import Testing
import SuiteKernel

@Suite struct DocumentSessionTests {
    static let start = Date(timeIntervalSince1970: 1_000)

    /// A session saved at token 3, then edited to token 4 at `start`.
    static func editedSession() -> DocumentSession {
        var session = DocumentSession(token: 0)
        session.didSave(token: 3)
        session.didEdit(token: 4, at: start)
        return session
    }

    @Test func freshSessionIsClean() {
        let session = DocumentSession(token: 7)
        #expect(session.savedToken == 7 && session.currentToken == 7)
        #expect(!session.isDirty)
        #expect(session.status == .unsaved)
        #expect(session.lastEdit == nil && session.lastAutosave == nil)
    }

    @Test func editMakesDirty() {
        let session = Self.editedSession()
        #expect(session.savedToken == 3)
        #expect(session.currentToken == 4)
        #expect(session.lastEdit == Self.start)
        #expect(session.isDirty)
    }

    /// Dirty is saved-vs-current, not a flag set on edit: undo back to the
    /// saved step reads clean, and redo past it reads dirty again.
    @Test func cleanAfterUndoToSaved() {
        var session = Self.editedSession()
        session.didEdit(token: 3, at: Self.start.addingTimeInterval(1))
        #expect(session.currentToken == 3)
        #expect(!session.isDirty)
        session.didEdit(token: 4, at: Self.start.addingTimeInterval(2))
        #expect(session.isDirty)
        // A different step than the saved one, even an older one, is dirty.
        session.didEdit(token: 2, at: Self.start.addingTimeInterval(3))
        #expect(session.isDirty)
    }

    @Test func saveNamesStatusAndCleans() {
        var session = Self.editedSession()
        session.didSave(token: 4)
        #expect(session.savedToken == 4)
        #expect(session.status == .saved)
        #expect(!session.isDirty)
        // An edit after the save leaves the saved token where it was.
        session.didEdit(token: 5, at: Self.start.addingTimeInterval(1))
        #expect(session.savedToken == 4 && session.isDirty)
    }

    @Test func statusCasesAreDistinct() {
        let all: [SaveStatus] = [.unsaved, .saved, .saving, .failed("Disk full"), .readOnly]
        #expect(Set(all).count == 5)
        #expect(SaveStatus.failed("Disk full") != .failed("No access"))
        let session = DocumentSession(token: 0, status: .readOnly)
        #expect(session.status == .readOnly)
    }

    @Test func autosaveDueAfterDelay() {
        let session = Self.editedSession()
        #expect(!session.autosaveDue(now: Self.start.addingTimeInterval(4.9), delay: 5))
        #expect(session.autosaveDue(now: Self.start.addingTimeInterval(5), delay: 5))
        #expect(session.autosaveDue(now: Self.start.addingTimeInterval(60), delay: 5))
    }

    @Test func autosaveNotDueWhenClean() {
        var session = Self.editedSession()
        session.didSave(token: 4)
        #expect(!session.autosaveDue(now: Self.start.addingTimeInterval(60), delay: 5))
        let fresh = DocumentSession()
        #expect(!fresh.autosaveDue(now: Self.start.addingTimeInterval(60), delay: 5))
    }

    /// The delay runs from the last edit, not from the last autosave: an old
    /// autosave does not make a fresh edit due at once, and an autosave after
    /// the last edit means nothing is due.
    @Test func dueMeasuresFromLastEdit() {
        var session = Self.editedSession()
        session.lastAutosave = Self.start.addingTimeInterval(-100)
        #expect(!session.autosaveDue(now: Self.start.addingTimeInterval(1), delay: 5))
        #expect(session.autosaveDue(now: Self.start.addingTimeInterval(5), delay: 5))
        session.lastAutosave = Self.start.addingTimeInterval(6)
        #expect(!session.autosaveDue(now: Self.start.addingTimeInterval(60), delay: 5))
        session.didEdit(token: 5, at: Self.start.addingTimeInterval(10))
        #expect(!session.autosaveDue(now: Self.start.addingTimeInterval(12), delay: 5))
        #expect(session.autosaveDue(now: Self.start.addingTimeInterval(15), delay: 5))
    }

    @Test func autosaveRefusesNonFiniteDelay() {
        let session = Self.editedSession()
        #expect(!session.autosaveDue(now: Self.start.addingTimeInterval(60), delay: .nan))
        #expect(!session.autosaveDue(now: Self.start.addingTimeInterval(60), delay: .infinity))
    }

    /// The recovery alert asks a question that names the document; it is
    /// more than the bare name.
    @Test func recoveryPromptNamesTheDocument() {
        let offer = RecoveryOffer(name: "Poster", savedAt: Self.start)
        #expect(offer.name == "Poster" && offer.savedAt == Self.start)
        #expect(offer.prompt.contains("Poster"))
        #expect(offer.prompt != "Poster")
        #expect(offer.prompt.hasSuffix("?"))
        let other = RecoveryOffer(name: "Banner", savedAt: Self.start)
        #expect(other.prompt.contains("Banner") && !other.prompt.contains("Poster"))
    }

    // MARK: KJ8

    /// KJ8, the session walk: open a versioned file, edit, autosave, undo back
    /// to the saved step, save, and offer the autosave back after a crash.
    @Test func sessionWalk() throws {
        let file = Data(#"{"version": 2, "layers": []}"#.utf8)
        #expect(try VersionedJSON.probe(file, supported: 2) == 2)
        #expect(throws: VersionError.newer(found: 2, supported: 1)) { try VersionedJSON.probe(file, supported: 1) }

        var session = DocumentSession(token: 0, status: .saved)
        #expect(!session.isDirty && !session.autosaveDue(now: Self.start, delay: 5))
        session.didEdit(token: 1, at: Self.start)
        session.didEdit(token: 2, at: Self.start.addingTimeInterval(2))
        #expect(session.isDirty)
        #expect(!session.autosaveDue(now: Self.start.addingTimeInterval(6), delay: 5))
        #expect(session.autosaveDue(now: Self.start.addingTimeInterval(7), delay: 5))
        session.lastAutosave = Self.start.addingTimeInterval(7)
        #expect(!session.autosaveDue(now: Self.start.addingTimeInterval(30), delay: 5))
        let offer = RecoveryOffer(name: "Poster", savedAt: Self.start.addingTimeInterval(7))
        #expect(offer.prompt.contains("Poster") && offer.prompt.hasSuffix("?"))

        session.didEdit(token: 1, at: Self.start.addingTimeInterval(8))
        session.didEdit(token: 0, at: Self.start.addingTimeInterval(9))
        #expect(!session.isDirty && !session.autosaveDue(now: Self.start.addingTimeInterval(60), delay: 5))
        session.didEdit(token: 3, at: Self.start.addingTimeInterval(10))
        session.didSave(token: 3)
        #expect(session.status == .saved && !session.isDirty)
        #expect(!session.autosaveDue(now: Self.start.addingTimeInterval(60), delay: 5))
    }
}
