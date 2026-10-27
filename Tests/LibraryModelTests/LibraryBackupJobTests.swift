// LibraryBackupJobTests.swift (catalog-backup BK-5): RJ-L54, Tests/RealJobs/library/restore-backup, run on Linux
// with the job's clock, since the CLI has no clock, truncation or relaunch (#3741). Each metadata.set-rating is
// followed by a save an hour after the last, which keeps a backup; then the catalog file is truncated and the app
// relaunched, which opens the newest good backup; the job's last steps restore the oldest and list the backups.
// Also the launch's backups: beside the live catalog, seeded for a fixture under -LibraryFixtureBackups, else none.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import LibraryModel
import SuiteKernel
import SuiteModel
import Testing

@Suite struct LibraryBackupJobTests {
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("RealJobs/library/restore-backup")
    static let coding = LiveCatalogCoding()

    struct Script: Decodable {
        struct Relaunch: Decodable { var opens: String, rated: Int, notice: String }
        struct Listing: Decodable { var rows: Int, newestRated: Int }
        struct Expect: Decodable {
            var relaunch: Relaunch, restored: [String: Int], listing: Listing
            enum CodingKeys: String, CodingKey {
                case relaunch, restored = "out/thirty-catalog.json", listing = "catalog.backups"
            }
        }
        var steps: [CommandEnvelope], expect: Expect
    }

    static func temp() -> String {
        FileManager.default.temporaryDirectory.appendingPathComponent("LibraryBackupJobTests-\(UUID().uuidString)").path
    }
    static func rated(_ photos: [PhotoItem]) -> Int { photos.filter { $0.rating > 0 }.count }

    @Test func restoreBackupJob() throws {
        let script = try JSONDecoder().decode(Script.self, from: Data(contentsOf: Self.folder.appendingPathComponent("restore-backup.jobs.json")))
        let input = try LibraryHeadless.open(Data(contentsOf: Self.folder.appendingPathComponent("input/thirty.library")), name: "thirty.library")
        #expect(input.library.items.count == 30)
        let dir = Self.temp(), store = FileStore(folder: dir), commands = LibraryCatalog.catalog
        let launch = LibraryLaunch(arguments: ["-LibraryCatalogDir", dir])
        var catalog = LibraryCatalog()
        catalog.restore(input.library.items)
        catalog.attachBackups(launch.backups(catalogFolder: dir, scratch: Self.temp(), now: Date()))
        let backups = try #require(catalog.backup.backups)
        let split = try #require(script.steps.firstIndex { $0.id.hasPrefix("catalog.") })
        var saves = 0
        for step in script.steps[..<split] {
            _ = try commands.run(step.id, params: step.params, on: &catalog)
            guard step.id == "metadata.set-rating" else { continue }
            try store.writeData("catalog.json", Self.coding.encode(catalog.items))
            try backups.didSave(now: Date(timeIntervalSince1970: 1_790_000_000 + Double(saves) * 3600), force: false)
            saves += 1
        }
        #expect(saves == 3 && backups.rows().count == 3)
        let saved = try #require(try store.readData("catalog.json"))
        try store.writeData("catalog.json", saved.prefix(saved.count / 2))

        // The relaunch: the catalog doesn't decode, so the newest good backup opens and is named.
        var relaunched = LibraryCatalog()
        relaunched.attachBackups(launch.backups(catalogFolder: dir, scratch: Self.temp(), now: Date()))
        #expect((try? Self.coding.decode(try #require(try store.readData("catalog.json")))) == nil)
        let fallback = try #require(relaunched.backup.backups?.newestGood(damagedName: "catalog.json.bad"))
        relaunched.openBackup(fallback)
        #expect(fallback.entry.name == script.expect.relaunch.opens)
        #expect(Self.rated(relaunched.items) == script.expect.relaunch.rated)
        #expect(relaunched.backup.notice?.hasPrefix(script.expect.relaunch.notice) == true)
        try store.writeData("catalog.json", Self.coding.encode(relaunched.items)) // the window's save of the opened backup

        var results: [JSONValue] = []
        for step in script.steps[split...] { results.append(try commands.run(step.id, params: step.params, on: &relaunched).result) }
        #expect(Self.rated(relaunched.items) == script.expect.restored["rated"])
        let rows = try #require(results.last).decode([LibraryBackupRow].self)
        #expect(rows.count == script.expect.listing.rows)
        let newest = try #require(rows.first)
        let kept = try Self.coding.decode(try #require(try store.readData("Backups/" + newest.name)))
        #expect(Self.rated(kept) == script.expect.listing.newestRated, "catalog.backups lists the pre-restore catalog")
    }

    @Test func fixtureBackupsFlag() {
        #expect(LibraryLaunch(arguments: ["-LibraryFixture", "samples", "-LibraryFixtureBackups", "1"]).fixtureBackups)
        #expect(!LibraryLaunch(arguments: ["-LibraryFixture", "samples", "-LibraryFixtureBackups", "0"]).fixtureBackups)
        #expect(!LibraryLaunch(arguments: ["-LibraryFixture", "samples"]).fixtureBackups)
    }

    /// A fixture's backups: two days old with every rating 1, a day old with every rating 0, ten minutes old as
    /// given, and the catalog file as given, so a restore keeps one more; none without the flag.
    @Test func fixtureBackupsAreSeeded() throws {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let launch = LibraryLaunch(arguments: ["-LibraryFixture", "samples", "-LibraryFixtureBackups", "1"])
        #expect(LibraryLaunch(arguments: ["-LibraryFixture", "samples"]).backups(catalogFolder: nil, scratch: Self.temp(), now: now) == nil)
        let scratch = Self.temp()
        let backups = try #require(launch.backups(catalogFolder: "/unused", scratch: scratch, now: now))
        #expect(backups.rotation.store.folder == scratch)
        let photos = launch.initialPhotos
        #expect(!photos.isEmpty)
        let rows = backups.rows()
        #expect(rows.map(\.date) == [-600.0, -86_400, -172_800].map { now.timeIntervalSince1970 + $0 })
        #expect(rows.map(\.photos) == Array(repeating: photos.count, count: 3))
        let ratings = try rows.map { row in
            try Self.coding.decode(try #require(try backups.rotation.store.readData("Backups/" + row.name))).map(\.rating)
        }
        #expect(ratings == [photos.map(\.rating), photos.map { _ in 0 }, photos.map { _ in 1 }])
        #expect(try Self.coding.decode(try #require(try backups.rotation.store.readData("catalog.json"))) == photos)
    }

    @Test func liveBackupsBesideTheCatalog() throws {
        let dir = Self.temp()
        let backups = try #require(LibraryLaunch(arguments: []).backups(catalogFolder: dir, scratch: Self.temp(), now: Date()))
        #expect(backups.rotation.store.folder == dir && backups.rotation.file == "catalog.json")
        #expect(backups.rows().isEmpty)
        #expect(LibraryLaunch(arguments: []).backups(catalogFolder: nil, scratch: Self.temp(), now: Date()) == nil)
    }
}
