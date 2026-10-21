// BackupRotationTests.swift (catalog-backup BK-1 written, BK-3 on): rolling backups of one file over the suite
// store, in a temp folder, on a test clock. 30 saves over 3 hours make 3 backups; a forced backup within the hour
// is kept; 20 days of backups prune to the newest 10 plus the newest of each of the last 7 days, never the
// newest; a restore backs up the current file first. Disabled until BK-3 gives the rotation its bodies.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct BackupRotationTests {
    /// A rotation of "catalog.json" over a fresh store per test (tests run in parallel), and the store.
    static func make() -> (BackupRotation, FileStore) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("BackupRotationTests-\(UUID().uuidString)").path
        let store = FileStore(folder: folder)
        return (BackupRotation(store: store, file: "catalog.json"), store)
    }
    /// Whole seconds from a fixed start, so a date read back from a backup's name compares equal.
    static let start = Date(timeIntervalSince1970: 1_790_000_000)
    static func at(minutes: Int) -> Date { start.addingTimeInterval(Double(minutes) * 60) }
    static func save(_ store: FileStore, _ text: String) throws {
        try store.writeData("catalog.json", Data(text.utf8))
    }

    @Test(.disabled("waits on BK-3")) func thirtySavesOverThreeHoursMakeThree() throws {
        let (rotation, store) = Self.make()
        for i in 0..<30 {
            let now = Self.at(minutes: i * 6)
            try Self.save(store, "save \(i)")
            if rotation.shouldBackUp(now: now) { try rotation.backUp(now: now, force: false) }
        }
        #expect(rotation.list().map(\.date) == [Self.at(minutes: 120), Self.at(minutes: 60), Self.at(minutes: 0)])
    }

    @Test(.disabled("waits on BK-3")) func forcedWithinTheHourIsKept() throws {
        let (rotation, store) = Self.make()
        try Self.save(store, "one")
        try rotation.backUp(now: Self.at(minutes: 0), force: false)
        try Self.save(store, "two")
        let quit = try rotation.backUp(now: Self.at(minutes: 10), force: true)
        try rotation.prune(now: Self.at(minutes: 11))
        #expect(rotation.list().map(\.date) == [Self.at(minutes: 10), Self.at(minutes: 0)])
        #expect(rotation.list().first == quit)
        #expect(quit?.bytes == 3)
    }

    @Test(.disabled("waits on BK-3")) func twentyDaysPruneToTenPlusSevenDaily() throws {
        let (rotation, store) = Self.make()
        let day = 24 * 60
        // Two backups a day, at 09:00 and 18:00 from the start, for 20 days.
        for d in 0..<20 {
            for hour in [9, 18] {
                try Self.save(store, "day \(d) at \(hour)")
                try rotation.backUp(now: Self.at(minutes: d * day + hour * 60), force: true)
            }
        }
        let now = Self.at(minutes: 19 * day + 20 * 60)
        try rotation.prune(now: now)
        let kept = rotation.list().map(\.date)
        // The newest 10 are days 15 to 19, both copies; the last 7 days add the newest (18:00) of days 13 and 14.
        let newestTen = (15..<20).reversed().flatMap { d in [18, 9].map { Self.at(minutes: d * day + $0 * 60) } }
        let daily = [14, 13].map { Self.at(minutes: $0 * day + 18 * 60) }
        #expect(kept == newestTen + daily)
        #expect(kept.count <= 17)
        #expect(kept.first == Self.at(minutes: 19 * day + 18 * 60))
    }

    @Test(.disabled("waits on BK-3")) func pruneNeverDropsTheNewest() throws {
        let (rotation, store) = Self.make()
        try Self.save(store, "old")
        try rotation.backUp(now: Self.at(minutes: 0), force: true)
        try rotation.prune(now: Self.at(minutes: 60 * 24 * 365))
        #expect(rotation.list().map(\.date) == [Self.at(minutes: 0)])
    }

    @Test(.disabled("waits on BK-3")) func restoreBacksUpTheCurrentFileFirst() throws {
        let (rotation, store) = Self.make()
        try Self.save(store, "yesterday")
        let old = try #require(try rotation.backUp(now: Self.at(minutes: 0), force: true))
        try Self.save(store, "today")
        try rotation.restore(old.name, now: Self.at(minutes: 90))
        #expect(try store.readData("catalog.json") == Data("yesterday".utf8))
        let newest = try #require(rotation.list().first)
        #expect(newest.date == Self.at(minutes: 90))
        #expect(try store.readData("Backups/" + newest.name) == Data("today".utf8))
        #expect(rotation.list().count == 2)
    }

    @Test(.disabled("waits on BK-3")) func restoreOfAnUnknownNameChangesNothing() throws {
        let (rotation, store) = Self.make()
        try Self.save(store, "today")
        #expect(throws: SuiteError.self) { try rotation.restore("nope", now: Self.at(minutes: 0)) }
        #expect(try store.readData("catalog.json") == Data("today".utf8))
        #expect(rotation.list().isEmpty)
    }

    /// On now, BK-3 deletes it: the stubs never copy, never crash and refuse a restore with the reason.
    @Test func stubsCopyNothing() throws {
        let (rotation, store) = Self.make()
        try Self.save(store, "one")
        #expect(try rotation.backUp(now: Self.at(minutes: 0), force: true) == nil)
        #expect(rotation.list().isEmpty)
        #expect(!rotation.shouldBackUp(now: Self.at(minutes: 0)))
        #expect(throws: SuiteError.notAvailable(BackupRotation.unavailable)) { try rotation.restore("x", now: Self.at(minutes: 0)) }
    }
}
