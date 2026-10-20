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
import SuiteModel

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
    /// The autosave's bytes (history-panel PH-6): the open image's document
    /// package as one .ora container, its name inside (`photo/recovery.json`),
    /// its PNGs through CoreRaster's codec. Throws with no image open.
    public func recoveryBytes() throws -> Data {
        try recoveryBytes(codec: CoreRasterImageCodec())
    }

    /// The autosave's bytes, the layers' images through `codec` and the
    /// container through `services.archive`.
    public func recoveryBytes(codec: any PhotoImageCodec) throws -> Data {
        try LiveRecovery.container(
            documentPackage(codec: codec), info: LiveRecovery.Info(documentName: documentName), archive: services.archive)
    }

    /// The autosave's encode for the window: the workspace is copied now,
    /// on the caller's actor, and the returned closure encodes that copy
    /// wherever it runs (the autosave runs it detached, off the main actor).
    public func recoveryEncoder(codec: any PhotoImageCodec) -> @Sendable () throws -> Data {
        let copy = self
        return { try copy.recoveryBytes(codec: codec) }
    }

    /// The workspace an autosave's `data` restores, named `name` (else the
    /// name inside the bytes), on the live services and CoreRaster's codec.
    public static func recovered(from data: Data, name: String?) async throws -> PhotoWorkspace {
        try await recovered(from: data, name: name, services: .live, codec: CoreRasterImageCodec())
    }

    /// The workspace `data` restores on `services`, decoded off the caller's
    /// actor: dirty and unsaved, so Save asks where. Throws `ArchiveError` for
    /// bytes that don't open.
    public static func recovered(
        from data: Data, name: String?, services: PhotoServices, codec: any PhotoImageCodec
    ) async throws -> PhotoWorkspace {
        try await Task.detached {
            let (package, info) = try LiveRecovery.unpack(data, archive: services.archive)
            var workspace = PhotoWorkspace(services: services)
            try workspace.restore(
                RecoveryEntry(documentName: name ?? info?.documentName, savedAt: 0, package: package), codec: codec)
            return workspace
        }.value
    }

    /// Takes `restored` (from `recovered`) as the window's image, keeping
    /// this window's services.
    public mutating func restoreRecovered(_ restored: PhotoWorkspace) {
        let services = self.services
        self = restored
        self.services = services
    }
}

extension PhotoServices {
    /// The folder the window's autosave writes and offers through; nil when
    /// the recovery store isn't a folder on disk (the fakes).
    public var recoveryFolder: RecoveryFolder? { (recovery as? LiveRecovery)?.folder }
}
