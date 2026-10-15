// PhotoRecovery.swift: the Model side of autosave recovery (PV-1, PJ-3).
// When an autosave is due (`autosaveDue`: the image is dirty, `delay`
// seconds have passed since the last edit, and that edit isn't autosaved
// yet), the entry an autosave writes (`recoveryEntry`: the document package
// with the image's name and the time), restoring one (`restore`: the image
// comes back dirty and unsaved, so Save asks where) and the launch offer's
// text (`RecoveryOffer`). Times are seconds passed in by the caller, so none
// of this reads a clock. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The offer to restore an autosave a crash left behind.
public struct RecoveryOffer: Sendable, Equatable {
    public let entry: RecoveryEntry
    /// "Restore beach.png from 9:41 AM?", or "Restore the unsaved image from
    /// 9:41 AM?" for an image that never had a name.
    public let message: String

    /// `time` formats the entry's `savedAt` ("9:41 AM").
    public init(entry: RecoveryEntry, time: (Double) -> String) {
        self.entry = entry
        let what = entry.documentName ?? "the unsaved image"
        message = "Restore \(what) from \(time(entry.savedAt))?"
    }
}

extension PhotoWorkspace {
    /// Seconds after the last edit before the image autosaves (PJ-3).
    public static let autosaveDelay: Double = 5

    /// Whether to autosave now: the image is dirty, at least `delay` seconds
    /// have passed since `lastEdit`, and the last autosave came before that
    /// edit. False when any time is NaN or infinite.
    public func autosaveDue(
        lastEdit: Double, lastAutosave: Double?, now: Double, delay: Double = PhotoWorkspace.autosaveDelay
    ) -> Bool {
        guard isDirty, lastEdit.isFinite, now.isFinite, delay.isFinite, lastAutosave?.isFinite ?? true else {
            return false
        }
        return now - lastEdit >= delay && (lastAutosave ?? -.infinity) < lastEdit
    }

    /// What an autosave at `now` writes: the document package of the open
    /// image with its name, through `archive`. Nil when the image is clean or
    /// none is open.
    public func recoveryEntry(
        now: Double, archive: any DocumentArchiving, codec: any PhotoImageCodec
    ) throws -> RecoveryEntry? {
        guard isDirty else { return nil }
        return RecoveryEntry(
            documentName: documentName, savedAt: now, package: try documentPackage(archive: archive, codec: codec))
    }

    /// What an autosave at `now` writes, through `services.archive`.
    public func recoveryEntry(now: Double, codec: any PhotoImageCodec) throws -> RecoveryEntry? {
        try recoveryEntry(now: now, archive: services.archive, codec: codec)
    }

    /// Opens the autosaved document in `entry` through `services.archive`.
    public mutating func restore(_ entry: RecoveryEntry, codec: any PhotoImageCodec) throws {
        try restore(entry, archive: services.archive, codec: codec)
    }

    /// Opens the autosaved document in `entry` under its name (untitled when
    /// it had none). The image reads dirty until it is saved, even after
    /// undoing back, and Save asks where, since nothing is on disk yet.
    /// Throws `ArchiveError`; the workspace is unchanged.
    public mutating func restore(
        _ entry: RecoveryEntry, archive: any DocumentArchiving, codec: any PhotoImageCodec
    ) throws {
        try openDocument(entry.package, name: entry.documentName ?? "Untitled", archive: archive, codec: codec)
        documentName = entry.documentName
        fileKind = nil
        // Every step has an id, so nil matches none: the image never reads saved.
        savedStepID = nil
    }
}
