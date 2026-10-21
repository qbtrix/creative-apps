// PhotoRecovery+Kernel.swift: Photo's document session on SuiteKernel's
// (adopt-kernel-session, AD-photo). `documentSession` is the open image as a
// DocumentSession whose tokens are the history step ids, so `autosaveDue`
// asks the kernel; `PhotoSaveStatus.kernelStatus` is the save status as the
// kernel's SaveStatus; `RecoveryOffer.kernelOffer` is the launch offer as the
// kernel's; and `LiveArchive.probeFormat` reads photo/document.json's version
// through VersionedJSON.probe, mapping its refusals to ArchiveError. Photo's
// public API and its words stay as they were. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension PhotoWorkspace {
    /// The saved token of an image that was never saved (a restored
    /// autosave): history step ids start at 0, so no step has it.
    static let neverSavedToken = Int.min

    /// The open image's session: saved at the step last saved, opened or
    /// created, and at the step on screen now. Clean with no image open.
    var documentSession: DocumentSession {
        var session = DocumentSession(token: savedStepID ?? Self.neverSavedToken)
        guard canvas != nil else { return session }
        session.currentToken = currentStepID
        return session
    }

    /// The session with the last edit and autosave at `lastEdit` and
    /// `lastAutosave`, in the caller's seconds. Only their differences
    /// matter, so they sit on the reference date unconverted and the
    /// kernel's arithmetic is Photo's own.
    func autosaveSession(lastEdit: Double, lastAutosave: Double?) -> DocumentSession {
        var session = documentSession
        session.lastEdit = Date(timeIntervalSinceReferenceDate: lastEdit)
        session.lastAutosave = lastAutosave.map { Date(timeIntervalSinceReferenceDate: $0) }
        return session
    }
}

extension PhotoSaveStatus {
    /// The words of a save that didn't finish.
    static let failedWords = "The last save didn't finish. Try File > Save As\u{2026} to choose another folder."

    /// This status as the kernel's: saved, edited (autosaved or not) as
    /// unsaved, and a failed save with its words.
    public var kernelStatus: SaveStatus {
        switch self {
        case .saved: .saved
        case .edited, .editedAutosaved: .unsaved
        case .notSaved: .failed(Self.failedWords)
        }
    }
}

extension RecoveryOffer {
    /// The offer as the kernel's: the document's name ("Untitled" when it
    /// had none) and when it was autosaved (`savedAt` counts from 1970).
    public var kernelOffer: SuiteKernel.RecoveryOffer {
        SuiteKernel.RecoveryOffer(
            name: entry.documentName ?? "Untitled", savedAt: Date(timeIntervalSince1970: entry.savedAt))
    }
}

extension LiveArchive {
    /// The format version of `json` through the kernel's probe: one newer
    /// than `supported` throws `newerVersion`, one it can't read `unreadable`.
    static func probeFormat(_ json: Data, supported: Int, unreadable: ArchiveError) throws(ArchiveError) -> Int {
        do {
            return try VersionedJSON.probe(json, key: "format", supported: supported)
        } catch {
            switch error {
            case .newer(let found, _): throw .newerVersion(found)
            case .damaged, .missing: throw unreadable
            }
        }
    }
}

extension PhotoWorkspace {
    /// The autosave's bytes: the .ora container of `recoveryEntry`
    /// (history-panel PH-1 declares it; PH-6 writes the body). Throws until then.
    public func recoveryBytes() throws -> Data {
        throw ArchiveError.damaged("recoveryBytes waits on history-panel PH-6")
    }

    /// The workspace an autosave's `data` restores, named `name`
    /// (history-panel PH-1 declares it; PH-6 writes the body). Throws until then.
    public static func recovered(from data: Data, name: String?) async throws -> PhotoWorkspace {
        throw ArchiveError.damaged("recovered(from:name:) waits on history-panel PH-6")
    }
}
