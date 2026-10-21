// LibraryBackupTests.swift (catalog-backup BK-2 written, BK-5m on): Library's catalog backups over the suite
// store's rotation, in a temp folder with the live catalog coding. A damaged catalog with good and damaged
// backups opens the newest one that decodes and says so; restoring an older backup leaves a backup of the current
// catalog and brings back its ratings; a backup after a save runs off the main thread. Runs on Linux and macOS.
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

    @Test(.disabled("waits on BK-5m")) func damagedCatalogOpensTheNewestGoodBackup() throws {
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

    @Test(.disabled("waits on BK-5m")) func restoreKeepsTheCurrentCatalogAsABackup() throws {
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

    @Test(.disabled("waits on BK-5m")) func backupOffMain() async throws {
        let (backups, store) = Self.make()
        try store.writeData("catalog.json", Self.coding.encode(Self.shoot(rated: 2)))
        try await Task.detached { try backups.didSave(now: Self.at(hours: 0), force: false) }.value
        #expect(backups.rows().map(\.date) == [Self.at(hours: 0).timeIntervalSince1970])
    }

    /// On now: both commands are declared, restore is off with the reason, and every run refuses.
    @Test func specsAreStubs() throws {
        #expect(LibraryCatalog.backupSpecs.map(\.id) == ["catalog.backups", "catalog.restore-backup"])
        var catalog = LibraryCatalog()
        let commands = try CommandCatalog(app: "library", LibraryCatalog.backupSpecs, history: { LibraryCatalogSteps(catalog: $0) })
        let why = LibraryBackups.unavailable
        #expect(throws: CatalogError.notBuilt(id: "catalog.backups", feature: "catalog-backup BK-5m")) {
            try commands.run("catalog.backups", params: .object([:]), on: &catalog)
        }
        #expect(throws: CatalogError.unavailable(id: "catalog.restore-backup", why: why)) {
            try commands.run("catalog.restore-backup", params: .object(["name": .string("x")]), on: &catalog)
        }
        let (backups, _) = Self.make()
        #expect(throws: SuiteError.notAvailable(why)) { try backups.restore("x", now: Self.start) }
        #expect(backups.rows().isEmpty)
        #expect(backups.newestGood(damagedName: "catalog.json.bad") == nil)
    }
}
