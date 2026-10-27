// LibraryBackup+Kernel.swift (catalog-backup BK-2 stubs, BK-5m bodies): Library's adapter onto the suite store's
// `BackupRotation` (packet docs/blueprints/library/features/catalog-backup.md). The catalog file's backups live
// in "Backups/" beside it; `LibraryBackups` lists them with their date and photo count, opens the newest one that
// decodes when the catalog can't be read, and restores one (the rotation backs up the current catalog first).
// `catalog.backups` and `catalog.restore-backup {name}` are the last of the catalog's commands. The rotation's
// own rules (hourly, ten kept, current backed up before a restore) live in SuiteModel, not here. At launch
// (BK-5) the window attaches `LibraryLaunch.backups`: the live catalog's, or a fixture's seeded ones. Linux-safe.
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

/// The catalog's backups as its state: the attached backups (nil for a fixture, a preview or the CLI without a
/// folder) and the notice of a damaged catalog opened from a backup. Equal by folder, file and notice.
public struct LibraryBackupState: Sendable, Equatable {
    public internal(set) var backups: LibraryBackups?
    public internal(set) var notice: String?
    public init() {}
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.notice == rhs.notice && lhs.backups?.rotation.store.folder == rhs.backups?.rotation.store.folder
            && lhs.backups?.rotation.file == rhs.backups?.rotation.file
    }
}

/// The catalog file's backups over the suite store's rotation.
public struct LibraryBackups: Sendable {
    public let rotation: BackupRotation, coding: any CatalogCoding
    /// The backups of `file` in `store`'s folder, decoded with `coding`.
    public init(store: FileStore, file: String = "catalog.json", coding: any CatalogCoding) {
        (rotation, self.coding) = (BackupRotation(store: store, file: file), coding)
    }

    /// Why Restore can't run: no backups attached to this catalog, or an import running; a name not listed.
    public static let noBackups = "Library has no catalog backups yet."
    public static let importing = "Wait for the import to finish before restoring a backup."
    public static func unknown(_ name: String) -> String { "There's no catalog backup named \(name)." }

    /// Every backup that decodes, newest first, with its photo count.
    public func rows() -> [LibraryBackupRow] {
        rotation.list().compactMap { entry in
            photos(of: entry.name).map { LibraryBackupRow(name: entry.name, date: entry.date.timeIntervalSince1970, photos: $0.count) }
        }
    }

    /// After a save that succeeded: a backup when an hour has passed (or `force`, at quit), then a prune.
    /// Plain file work, so the caller runs it off the main actor.
    public func didSave(now: Date, force: Bool) throws(SuiteError) {
        guard try rotation.backUp(now: now, force: force) != nil else { return }
        try rotation.prune(now: now)
    }

    /// When the catalog can't be read: the newest backup that decodes, walking newest first; nil when none does.
    /// The date reads at `utcOffset` seconds from UTC.
    public func newestGood(damagedName: String, utcOffset: Int = 0) -> LibraryBackupFallback? {
        for entry in rotation.list() {
            guard let photos = photos(of: entry.name) else { continue }
            let date = LibraryCatalog.dateText(entry.date, utcOffset: utcOffset)
            let message = "Opened the backup from \(date); the damaged catalog is kept as \(damagedName)."
            return LibraryBackupFallback(photos: photos, entry: entry, message: message)
        }
        return nil
    }

    /// Backs up the current catalog, replaces it with `name` and returns the restored photos. An unknown name
    /// throws `fileMissing` and a backup that doesn't decode `damaged`; neither changes anything.
    public func restore(_ name: String, now: Date) throws(SuiteError) -> [PhotoItem] {
        guard rotation.list().contains(where: { $0.name == name }), let data = try rotation.store.readData(Self.folder + name)
        else { throw .fileMissing(name: name) }
        guard let photos = try? coding.decode(data) else { throw .damaged(name) }
        try rotation.restore(name, now: now)
        return photos
    }

    /// The backups' folder beside the catalog, as the rotation names it.
    static let folder = "Backups/"

    /// The photos of the backup `name`; nil when it can't be read or doesn't decode.
    private func photos(of name: String) -> [PhotoItem]? {
        guard let data = try? rotation.store.readData(Self.folder + name) else { return nil }
        return try? coding.decode(data)
    }
}

extension LibraryBackups {
    /// The backups of "catalog.json" in `folder`, in the catalog file's format.
    public init(folder: String) { self.init(store: FileStore(folder: folder), coding: LiveCatalogCoding()) }

    /// A fixture's backups: `photos` as the catalog file, kept two days before `now` with every rating 1, a day
    /// before with every rating 0 and ten minutes before as given, so Restore has a yesterday to bring back.
    func seed(_ photos: [PhotoItem], now: Date) throws {
        let rated = { (stars: Int) in photos.map { var p = $0; p.rating = stars; return p } }
        for (age, set) in [(172_800.0, rated(1)), (86_400, rated(0)), (600, photos)] {
            try rotation.store.writeData(rotation.file, coding.encode(set))
            _ = try rotation.backUp(now: now.addingTimeInterval(-age), force: true)
        }
    }
}

extension LibraryLaunch {
    /// The catalog's backups at launch: beside the live catalog in `catalogFolder`; for a fixture, none unless
    /// `-LibraryFixtureBackups`, which seeds them in `scratch`; nil without a folder or when seeding fails.
    public func backups(catalogFolder: String?, scratch: String, now: Date) -> LibraryBackups? {
        guard fixture != nil || largeFixture != nil else { return catalogFolder.map { LibraryBackups(folder: $0) } }
        guard fixtureBackups else { return nil }
        let backups = LibraryBackups(folder: scratch)
        do { try backups.seed(initialPhotos, now: now) } catch { return nil }
        return backups
    }
}

extension LibraryCatalog {
    struct RestoreBackupParams: Codable, Sendable { var name: String }

    /// Why Restore can't run on `c` now: an import running, or no backups attached; nil when it can.
    static func restoreHelp(_ c: LibraryCatalog) -> String? {
        if case .running = c.importState { return LibraryBackups.importing }
        return c.backup.backups == nil ? LibraryBackups.noBackups : nil
    }

    /// `catalog.backups` and `catalog.restore-backup`, the last of `commands`. Restore replaces the photos and
    /// marks the catalog saved, since the file on disk is now the backup.
    public static let backupSpecs: [CommandSpec<LibraryCatalog>] = [
        .typed("catalog.backups", title: "Catalog Backups", summary: "Lists the catalog's backups, newest first, with date and photo count.",
               kind: .query, params: NoParams.self, schema: ParamSchema.none,
               result: .array(of: .object(["name": .string("The backup's file name."), "date": .number("Seconds since 1970."),
                                           "photos": .integer("Its photo count.", minimum: 0)], required: ["name", "date", "photos"])),
               example: .object([:])
        ) { c, _ -> [LibraryBackupRow] in c.backup.backups?.rows() ?? [] },
        .typed("catalog.restore-backup", title: "Restore Catalog Backup",
               summary: "Backs up the current catalog, then replaces it with the named backup. Not an undo step.",
               kind: .file, params: RestoreBackupParams.self,
               schema: .object(["name": .string("A backup's name from catalog.backups.")], required: ["name"]),
               example: .object(["name": .string("catalog 2026-10-20 18-00-00.json")]),
               availability: { available(restoreHelp($0)) }
        ) { c, p -> JSONValue in
            let unknown = CatalogError.unavailable(id: "catalog.restore-backup", why: LibraryBackups.unknown(p.name))
            guard let backups = c.backup.backups else { throw unknown }
            let photos: [PhotoItem]
            do throws(SuiteError) { photos = try backups.restore(p.name, now: Date()) } catch {
                guard case .fileMissing = error else { throw CatalogError.unavailable(id: "catalog.restore-backup", why: error.message) }
                throw unknown
            }
            c.restore(photos)
            return .object(["name": .string(p.name)])
        },
    ]
}

/// The Restore controls as they read their state: why restoring can't run now, nil when it can.
public struct LibraryRestoreControl: Sendable, Equatable {
    public var help: String?
    public init(help: String?) { self.help = help }
}

extension LibraryCatalog {
    /// File > Restore Catalog Backup…, the sheet's Restore… and its confirmation's Restore (`file.restore-backup`):
    /// controls over `catalog.restore-backup` that open or confirm the sheet, so the spec stays out of `commands`
    /// (and the ledger) like `file.share`; it is available while the control's help is nil.
    public static let restoreControlSpec: CommandSpec<LibraryRestoreControl> =
        .typed("file.restore-backup", title: "Restore Catalog Backup",
               summary: "Backs up the current catalog, then replaces it with the chosen backup.", kind: .file,
               params: NoParams.self, schema: ParamSchema.none, example: .object([:]), availability: { available($0.help) }
        ) { _, _ -> JSONValue in .object([:]) }
}
