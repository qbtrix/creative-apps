// HaloFiles+Kernel.swift (AD-h1): Halo's file state on the editor kernel's
// session. `file.unsaved` and `file.error` read as a `DocumentSession` whose
// current token is one past the saved one while the work isn't on disk, so the
// save status and subtitle are the kernel's `SaveStatus` in Halo's words; a
// save closes the open coalescing run (the kernel's `endRun`), so the next
// scrub is its own step and undo lands on the saved document; the envelope's
// version is read with `VersionedJSON.probe`, its refusals mapped to
// `HaloFileError`. Linux-safe: no UI imports.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension HaloProject {
    /// The file state as the kernel's session: dirty while unsaved; the status
    /// is `failed` after a failed save, `unsaved` before any save or open,
    /// else `saved`.
    var session: DocumentSession {
        var session = DocumentSession(token: 0, status: Self.status(of: file))
        session.currentToken = file.unsaved ? 1 : 0
        return session
    }

    /// The kernel status for `file`.
    static func status(of file: HaloFileState) -> SaveStatus {
        if file.unsaved, let error = file.error { return .failed(error) }
        return file.path == nil ? .unsaved : .saved
    }

    /// "Not saved" after a failed save, "Edited" while dirty, "Untitled"
    /// before any save or open, else "Saved".
    static func words(for session: DocumentSession) -> String {
        if case .failed = session.status { return "Not saved" }
        if session.isDirty { return "Edited" }
        if case .unsaved = session.status { return "Untitled" }
        return "Saved"
    }

    /// Records the save on the session's side: the open run ends, as the
    /// kernel's `endRun` does after a save, so the saved step stays the saved one.
    mutating func sessionDidSave() {
        endCoalescing()
    }
}

extension HaloFileFormat {
    /// The envelope's version through `VersionedJSON.probe`: a newer one is
    /// `.newerVersion(found)`, a missing or unreadable one `.notAHaloFile`.
    static func probeVersion(_ data: Data) throws(HaloFileError) -> Int {
        do throws(VersionError) {
            return try VersionedJSON.probe(data, supported: version)
        } catch {
            switch error {
            case .newer(let found, _): throw .newerVersion(found)
            case .damaged, .missing: throw .notAHaloFile
            }
        }
    }
}
