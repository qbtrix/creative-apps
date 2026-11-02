// FlareFiles+Kernel.swift (AD-f1): Flare's file state on the editor kernel's session. `documentSession` is the
// open document as a `DocumentSession`: saved at token 0, and one step past it while the document differs from the
// one last opened or saved (FlareCore's CommandEngine publishes no step id, so the token is read from the document),
// so `isDirty` is the session's and undoing back to the save reads clean. `autosaveDue` asks the kernel with Flare's
// 30 s delay. A save ends the open coalescing run, as the kernel's `History.endRun` does, so a scrub that goes on
// after a save is its own step and undo lands on the saved document. The launch offer is the kernel's
// `RecoveryOffer`. Open Recent is the suite's `RecentsList` (FlareFileFlow+Kernel.swift).
// Linux-safe: no UI imports.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

/// The kernel's recovery offer, so app files can name it without importing SuiteKernel.
public typealias FlareRecoveryOffer = SuiteKernel.RecoveryOffer

extension FlareWorkspace {
    /// The open document's session: clean at the document last opened or saved, one step past it otherwise.
    var documentSession: DocumentSession {
        var session = DocumentSession(token: 0)
        session.currentToken = document == savedDocument ? session.savedToken : session.savedToken + 1
        return session
    }

    /// The session with its last edit at `lastEdit`, in the caller's seconds. Only the difference to `now`
    /// matters, so both sit on the reference date unconverted and the kernel's arithmetic is Flare's own.
    func autosaveSession(lastEdit: Double) -> DocumentSession {
        var session = documentSession
        session.lastEdit = Date(timeIntervalSinceReferenceDate: lastEdit)
        return session
    }

    /// Whether the kernel says autosave is due at `now` for an edit at `lastEdit`, with `autosaveDelay`.
    func kernelAutosaveDue(lastEdit: Double, now: Double) -> Bool {
        autosaveSession(lastEdit: lastEdit)
            .autosaveDue(now: Date(timeIntervalSinceReferenceDate: now), delay: Self.autosaveDelay)
    }

    /// Records the save on the session's side: every open drag or scrub run ends, so the next edit is a step of
    /// its own and the saved step stays the saved one.
    mutating func sessionDidSave() {
        endCoalescing()
    }

    /// Ends every coalescing run: property scrubs, easing handle drags, guide drags, key drags and path drags.
    mutating func endCoalescing() {
        pathDrag = nil
        propertyScrubSerial &+= 1
        easingDragSerial &+= 1
        guideDragSerial &+= 1
        keyDragSerial &+= 1
    }

    /// The launch offer for a recovery file written at `savedAt`: an unsaved document has no name, so "Untitled".
    public static func recoveryOffer(savedAt: Date) -> FlareRecoveryOffer {
        FlareRecoveryOffer(name: "Untitled", savedAt: savedAt)
    }
}
