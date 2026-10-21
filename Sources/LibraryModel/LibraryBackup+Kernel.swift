// LibraryBackup+Kernel.swift (catalog-backup BK-2 stubs, BK-5m bodies): Library's adapter onto the suite store's
// `BackupRotation` (packet docs/blueprints/library/features/catalog-backup.md). The catalog file's backups live
// in "Backups/" beside it; `LibraryBackups` lists them with their date and photo count, opens the newest one that
// decodes when the catalog can't be read, and restores one (the rotation backs up the current catalog first).
// `catalog.backups` and `catalog.restore-backup {name}` are the commands; BK-5m appends them to the catalog.
// BK-2: the shape only. The rows are empty, the fallback finds nothing and every run throws
// the kernel's `CatalogError.notBuilt`. No rotation logic lives here. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel
import SuiteModel

/// One backup as the Restore sheet and `catalog.backups` show it: its name, when it was made and its photos.
public struct LibraryBackupRow: Codable, Hashable, Sendable {
    /// The date is seconds since 1970, as the command's JSON carries it.
    public var name: String, date: Double, photos: Int
    public init(name: String, date: Double, photos: Int) { (self.name, self.date, self.photos) = (name, date, photos) }
}

/// What opening a backup in place of an unreadable catalog found: its photos, the backup, and the notice.
public struct LibraryBackupFallback: Sendable, Equatable {
    /// The message reads "Opened the backup from <date>; the damaged catalog is kept as …".
    public var photos: [PhotoItem], entry: BackupEntry, message: String
    public init(photos: [PhotoItem], entry: BackupEntry, message: String) {
        (self.photos, self.entry, self.message) = (photos, entry, message)
    }
}

/// The catalog file's backups over the suite store's rotation.
public struct LibraryBackups: Sendable {
    public let rotation: BackupRotation, coding: any CatalogCoding
    /// The backups of `file` in `store`'s folder, decoded with `coding`.
    public init(store: FileStore, file: String = "catalog.json", coding: any CatalogCoding) {
        (rotation, self.coding) = (BackupRotation(store: store, file: file), coding)
    }

    /// Why the backup actions are off until BK-5m gives them bodies, in the words the menu shows.
    public static let unavailable = BackupRotation.unavailable

    /// Every backup that decodes, newest first, with its photo count. BK-2: none.
    public func rows() -> [LibraryBackupRow] { [] }

    /// After a save that succeeded: a backup when an hour has passed (or `force`, at quit), then a prune. BK-2: nothing.
    public func didSave(now: Date, force: Bool) throws(SuiteError) {}

    /// When the catalog can't be read: the newest backup that decodes, walking newest first; nil when none does.
    /// BK-2: nil.
    public func newestGood(damagedName: String) -> LibraryBackupFallback? { nil }

    /// Backs up the current catalog, replaces it with `name` and returns the restored photos. BK-2: refuses.
    public func restore(_ name: String, now: Date) throws(SuiteError) -> [PhotoItem] {
        throw .notAvailable(Self.unavailable)
    }
}

extension LibraryCatalog {
    /// The kernel's not-built refusal for each backup command until BK-5m gives it a body.
    static func backupNotBuilt(_ id: String) -> CatalogError { .notBuilt(id: id, feature: "catalog-backup BK-5m") }
    struct RestoreBackupParams: Codable, Sendable { var name: String }

    /// `catalog.backups` and `catalog.restore-backup`; BK-5m appends them to `commands` and the ledger.
    public static let backupSpecs: [CommandSpec<LibraryCatalog>] = [
        .typed("catalog.backups", title: "Catalog Backups", summary: "Lists the catalog's backups, newest first, with date and photo count.",
               kind: .query, params: NoParams.self, schema: ParamSchema.none,
               result: .array(of: .object(["name": .string("The backup's file name."), "date": .number("Seconds since 1970."),
                                           "photos": .integer("Its photo count.", minimum: 0)], required: ["name", "date", "photos"])),
               example: .object([:])
        ) { _, _ -> [LibraryBackupRow] in throw backupNotBuilt("catalog.backups") },
        .typed("catalog.restore-backup", title: "Restore Catalog Backup",
               summary: "Backs up the current catalog, then replaces it with the named backup. Not an undo step.",
               kind: .file, params: RestoreBackupParams.self,
               schema: .object(["name": .string("A backup's name from catalog.backups.")], required: ["name"]),
               example: .object(["name": .string("catalog 2026-10-20 18-00-00.json")]),
               availability: { _ in .unavailable(LibraryBackups.unavailable) }
        ) { _, _ -> JSONValue in throw backupNotBuilt("catalog.restore-backup") },
    ]
}
