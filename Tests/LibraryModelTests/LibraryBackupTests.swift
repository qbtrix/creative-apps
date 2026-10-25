// LibraryBackupTests.swift (catalog-backup BK-2 written, BK-5m on): Library's catalog backups over the suite
// store's rotation, in a temp folder with the live catalog coding. A damaged catalog with good and damaged
// backups opens the newest one that decodes and says so; restoring an older backup leaves a backup of the current
// catalog and brings back its ratings; a backup after a save runs off the main thread; the two commands list and
// restore on the catalog. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import LibraryModel
import SuiteKernel
import SuiteModel
import Testing

@Suite struct LibraryBackupTests {
    static let coding = LiveCatalogCoding()
    static let start = Date(timeIntervalSince1970: 1_790_000_000)
    static func at(hours: Int) -> Date { start.addingTimeInterval(Double(hours) * 3600) }

    /// Backups of "catalog.json" over a fresh store per test, and the store.
    static func make() -> (LibraryBackups, FileStore) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LibraryBackupTests-\(UUID().uuidString)").path
        let store = FileStore(folder: folder)
        return (LibraryBackups(store: store, coding: coding), store)
    }
    /// The shoot fixture with every photo rated `stars`.
    static func shoot(rated stars: Int) -> [PhotoItem] {
        LibraryFixtures.photos(named: "shoot").map { var p = $0; p.rating = stars; return p }
    }
    /// Saves `photos` as the catalog, then forces a backup at `now`.
    static func saveAndBackUp(_ photos: [PhotoItem], _ backups: LibraryBackups, _ store: FileStore, at now: Date) throws -> BackupEntry? {
        try store.writeData("catalog.json", coding.encode(photos))
        return try backups.rotation.backUp(now: now, force: true)
    }

    @Test func damagedCatalogOpensTheNewestGoodBackup() throws {
        let (backups, store) = Self.make()
        _ = try Self.saveAndBackUp(Self.shoot(rated: 2), backups, store, at: Self.at(hours: 0))
        let good = try #require(try Self.saveAndBackUp(Self.shoot(rated: 4), backups, store, at: Self.at(hours: 1)))
        let bad = try #require(try Self.saveAndBackUp(Self.shoot(rated: 5), backups, store, at: Self.at(hours: 2)))
        try store.writeData("Backups/" + bad.name, Data("not a catalog".utf8))
        try store.writeData("catalog.json", Data("{\"truncated".utf8))
        let fallback = try #require(backups.newestGood(damagedName: "catalog.json.bad"))
        #expect(fallback.entry == good)
        #expect(fallback.photos == Self.shoot(rated: 4))
        #expect(fallback.message.hasPrefix("Opened the backup from"))
        #expect(fallback.message.contains("catalog.json.bad"))
    }

    @Test func restoreKeepsTheCurrentCatalogAsABackup() throws {
        let (backups, store) = Self.make()
        let yesterday = try #require(try Self.saveAndBackUp(Self.shoot(rated: 1), backups, store, at: Self.at(hours: 0)))
        try store.writeData("catalog.json", Self.coding.encode(Self.shoot(rated: 3)))
        let restored = try backups.restore(yesterday.name, now: Self.at(hours: 24))
        #expect(restored.map(\.rating) == Self.shoot(rated: 1).map(\.rating))
        #expect(try Self.coding.decode(try #require(try store.readData("catalog.json"))) == Self.shoot(rated: 1))
        let rows = backups.rows()
        #expect(rows.count == 2)
        let newest = try #require(rows.first)
        #expect(newest.date == Self.at(hours: 24).timeIntervalSince1970)
        #expect(newest.photos == Self.shoot(rated: 3).count)
        let kept = try #require(try store.readData("Backups/" + newest.name))
        #expect(try Self.coding.decode(kept).map(\.rating) == Self.shoot(rated: 3).map(\.rating))
    }

    @Test func backupOffMain() async throws {
        let (backups, store) = Self.make()
        try store.writeData("catalog.json", Self.coding.encode(Self.shoot(rated: 2)))
        try await Task.detached { try backups.didSave(now: Self.at(hours: 0), force: false) }.value
        #expect(backups.rows().map(\.date) == [Self.at(hours: 0).timeIntervalSince1970])
    }

    /// The commands on a catalog with its backups attached: the list names each backup, an unknown name and a
    /// running import are refused, and a restore reloads the backup's photos and keeps the current catalog.
    @Test func commandsListAndRestore() throws {
        #expect(LibraryCatalog.backupSpecs.map(\.id) == ["catalog.backups", "catalog.restore-backup"])
        let (backups, store) = Self.make()
        let first = try #require(try Self.saveAndBackUp(Self.shoot(rated: 1), backups, store, at: Self.at(hours: 0)))
        try store.writeData("catalog.json", Self.coding.encode(Self.shoot(rated: 3)))
        let commands = LibraryCatalog.catalog
        var catalog = LibraryCatalog()
        #expect(commands.availability("catalog.restore-backup", on: catalog).why == LibraryBackups.noBackups)
        catalog.restore(Self.shoot(rated: 3))
        catalog.attachBackups(backups)
        let rows = try commands.run("catalog.backups", params: .object([:]), on: &catalog).result.decode([LibraryBackupRow].self)
        let count = Self.shoot(rated: 1).count
        #expect(rows == [LibraryBackupRow(name: first.name, date: Self.at(hours: 0).timeIntervalSince1970, photos: count)])
        #expect(throws: CatalogError.unavailable(id: "catalog.restore-backup", why: LibraryBackups.unknown("nope"))) {
            try commands.run("catalog.restore-backup", params: .object(["name": .string("nope")]), on: &catalog)
        }
        var importing = catalog
        _ = importing.beginImport()
        #expect(commands.availability("catalog.restore-backup", on: importing).why == LibraryBackups.importing)
        _ = try commands.run("catalog.restore-backup", params: .object(["name": .string(first.name)]), on: &catalog)
        #expect(catalog.items.map(\.rating) == Self.shoot(rated: 1).map(\.rating))
        #expect(!catalog.catalogSession.isDirty, "the restored file is the saved catalog")
        #expect(backups.rows().count == 2)
    }

    /// A damaged catalog opens the newest good backup as unsaved photos and keeps the notice until dismissed.
    @Test func openBackupShowsTheNotice() throws {
        let (backups, store) = Self.make()
        _ = try Self.saveAndBackUp(Self.shoot(rated: 4), backups, store, at: Self.at(hours: 0))
        try store.writeData("catalog.json", Data("{".utf8))
        var catalog = LibraryCatalog()
        catalog.attachBackups(backups)
        let fallback = try #require(backups.newestGood(damagedName: "catalog.json.bad"))
        catalog.openBackup(fallback)
        #expect(catalog.items.map(\.rating) == Self.shoot(rated: 4).map(\.rating))
        #expect(catalog.catalogState == .ready)
        #expect(catalog.backup.notice == fallback.message)
        #expect(catalog.catalogSession.isDirty, "the opened backup is written as the catalog")
        catalog.dismissBackupNotice()
        #expect(catalog.backup.notice == nil)
    }

    /// Saves an hour apart each keep a backup, a save within the hour doesn't, a forced one does, and each
    /// backup prunes to the rotation's limits.
    @Test func didSavePrunes() throws {
        let (backups, store) = Self.make()
        try store.writeData("catalog.json", Self.coding.encode(Self.shoot(rated: 2)))
        for hour in 0..<12 { try backups.didSave(now: Self.at(hours: hour), force: false) }
        #expect(backups.rows().count == 10)
        let late = Self.at(hours: 11).addingTimeInterval(60)
        try backups.didSave(now: late, force: false)
        #expect(backups.rows().first?.date == Self.at(hours: 11).timeIntervalSince1970)
        try backups.didSave(now: late, force: true)
        #expect(backups.rows().first?.date == late.timeIntervalSince1970)
        #expect(backups.rows().count == 10)
    }
}
