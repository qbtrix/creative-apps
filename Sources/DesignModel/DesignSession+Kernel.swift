// DesignSession+Kernel.swift (AD-d1): Design's file state on the editor kernel's
// session. `documentSession` is the open document as a `DocumentSession` whose
// tokens are the kernel History's saved and current step ids (DesignHistory,
// #2938), so the session is dirty exactly when the workspace is and undoing back
// to the save reads clean. A save
// (`didSave(to:)`) records the current step as the session's saved token and
// ends the open edit run, as the kernel's `History.endRun` does after a save, so
// the next nudge is a step of its own. The file's version is read with
// `VersionedJSON.probe`, its refusals mapped to `DesignFileError`. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension DesignWorkspace {
    /// The open document's session: saved at the step last saved or opened, current
    /// at the step on screen now; `saved` once it has a location, else `unsaved`.
    /// Clean with nothing open.
    public var documentSession: DocumentSession {
        var session = DocumentSession(
            token: history.kernel.savedStepID, status: documentURL == nil ? .unsaved : .saved)
        guard isOpen else { return session }
        session.currentToken = history.kernel.currentStepID
        return session
    }

    /// Records a save on the session: the step on screen becomes the saved token,
    /// and the open edit run ends, so the saved step stays the saved one.
    mutating func sessionDidSave() {
        var session = documentSession
        session.didSave(token: history.kernel.currentStepID)
        history.kernel.savedStepID = session.savedToken
        endEditRun()
    }
}

extension LiveFiling {
    /// The file's version through the kernel's probe: a file that isn't a JSON
    /// object or has no integer version is `.unreadable`.
    static func probeVersion(_ data: Data) throws(DesignFileError) -> Int {
        do throws(VersionError) {
            return try VersionedJSON.probe(data)
        } catch {
            switch error {
            case .newer(let found, _): throw .unsupportedVersion(found)
            case .damaged, .missing: throw .unreadable
            }
        }
    }
}
