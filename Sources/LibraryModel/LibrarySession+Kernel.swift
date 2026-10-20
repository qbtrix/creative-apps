// LibrarySession+Kernel.swift (AD-l1): the catalog file's state on the editor
// kernel's session. `catalogSession` is catalog.json as a `DocumentSession`
// whose tokens are the catalog's revisions: every history step, undo and redo
// moves the revision by one, and so does an import, which records no step. The
// kernel's step ids can't be the tokens here: an import dirties the catalog with
// no step, and a save's answer arrives later naming the revision it wrote, which
// only a count that never rewinds can order (an undo rewinds the step id). Save
// ends no run: the window saves mid-drag, so a drag stays one step until
// `endCoalescing()` forwards to `History.endRun`. The file's version is read
// with `VersionedJSON.probe`, its refusals mapped to `LibraryError`. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension LibraryCatalog {
    /// The catalog file's session: saved at the revision last written (or
    /// read), current at the revision on screen now.
    public var catalogSession: DocumentSession {
        var session = DocumentSession(token: savedRevision)
        session.currentToken = saveRevision
        session.status = catalogSaveStatus(dirty: session.isDirty)
        return session
    }

    /// The save status: the last save's error, read-only while the file can't
    /// be saved over (loading, or newer), else unsaved while the session is dirty.
    func catalogSaveStatus(dirty: Bool) -> SaveStatus {
        if let saveError { return .failed(saveError) }
        guard catalogState.canSave else { return .readOnly }
        return dirty ? .unsaved : .saved
    }
}

extension LiveCatalogCoding {
    /// The file's version through the kernel's probe: one newer than this build
    /// reads is `newerCatalog`, a file with no integer version `damagedCatalog`.
    static func probeVersion(_ data: Data) throws(LibraryError) -> Int {
        do throws(VersionError) {
            return try VersionedJSON.probe(data, supported: version)
        } catch {
            switch error {
            case .newer(let found, _): throw .newerCatalog(version: found)
            case .damaged, .missing: throw .damagedCatalog("")
            }
        }
    }
}
