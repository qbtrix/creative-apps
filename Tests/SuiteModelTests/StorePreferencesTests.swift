// StorePreferencesTests.swift: the live PreferencesStoring over FileStore's
// preferences.json (onboarding OB-9's acceptance row and its store cost
// row, which is reported, not gated). A fresh temp folder per test.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1))) struct StorePreferencesTests {
    let store = FileStore(folder: FileManager.default.temporaryDirectory
        .appendingPathComponent("StorePreferencesTests-\(UUID().uuidString)").path)

    /// What preferences.json holds now, read straight from the store.
    func onDisk() throws -> (value: SuitePreferences?, revision: Int) {
        try store.read("preferences.json", as: SuitePreferences.self)
    }

    @Test func emptyLoadsDefaultsAndSaveWritesRevisionOne() async throws {
        let prefs = StorePreferences(store: store)
        var p = try await prefs.load()
        #expect(p == SuitePreferences() && p.revision == 0)
        p.homeOrder = [.library, .photo, .flare, .design, .halo]
        let saved = try await prefs.save(p)
        #expect(saved.revision == 1)
        #expect(try await prefs.load() == saved)
        #expect(try onDisk().revision == 1 && onDisk().value?.homeOrder == p.homeOrder)
    }

    @Test func aStaleSaveThrowsAndChangesNothing() async throws {
        let prefs = StorePreferences(store: store)
        let first = try await prefs.save(SuitePreferences(units: .inches))
        await #expect(throws: SuiteError.staleRevision) { try await prefs.save(SuitePreferences(units: .pixels)) }
        #expect(try await prefs.load() == first)
        #expect(try onDisk().revision == 1 && onDisk().value?.units == .inches)
        try store.write("preferences.json", SuitePreferences(units: .centimeters), expecting: 1)
        await #expect(throws: SuiteError.staleRevision) { try await prefs.save(first) }
        #expect(try onDisk().value?.units == .centimeters)
        let reloaded = try await prefs.load()
        #expect(reloaded.units == .centimeters && reloaded.revision == 2)
    }

    @Test func changesYieldEachNewRevisionOnce() async throws {
        let prefs = StorePreferences(store: store)
        var changes = await prefs.changes().makeAsyncIterator()
        let one = try await prefs.save(try await prefs.load())
        #expect(await changes.next() == 1)
        _ = try await prefs.save(one)
        #expect(await changes.next() == 2)
    }

    @Test func aSecondInstanceSeesTheWriteAfterExternalChange() async throws {
        let first = StorePreferences(store: store)
        let second = StorePreferences(store: FileStore(folder: store.folder))
        var secondChanges = await second.changes().makeAsyncIterator()
        _ = try await first.save(SuitePreferences(onboardingDoneVersion: 1))
        let read = try await second.load()
        #expect(read.onboardingDoneVersion == 1 && read.revision == 1)
        await second.externalChange()
        #expect(await secondChanges.next() == 1)
        await second.externalChange()          // nothing new: no yield
        _ = try await second.save(read)
        #expect(await secondChanges.next() == 2)
    }

    /// A save marks its own revision as seen: externalChange() after it (a watcher firing on this
    /// instance's own write) yields nothing, so the next value is the following save's.
    @Test func externalChangeAfterAnOwnSaveYieldsNothing() async throws {
        let prefs = StorePreferences(store: store)
        var changes = await prefs.changes().makeAsyncIterator()
        let one = try await prefs.save(try await prefs.load())
        #expect(await changes.next() == 1)
        await prefs.externalChange()           // its own write: already yielded
        _ = try await prefs.save(one)
        #expect(await changes.next() == 2)
    }

    @Test func onWriteIsCalledWithTheFileOnEverySave() async throws {
        let calls = Mutex<[String]>([])
        let prefs = StorePreferences(store: store) { name in calls.withLock { $0.append(name) } }
        _ = try await prefs.save(try await prefs.save(SuitePreferences()))
        await #expect(throws: SuiteError.staleRevision) { try await prefs.save(SuitePreferences()) }
        #expect(calls.withLock { $0 } == ["preferences.json", "preferences.json"])
    }

    /// The store cost row: `save` on a ~1 KB file, ≤ 2 ms on a device (as Budget+Store). Timing is
    /// printed, not asserted; the test only checks that every save landed.
    @Test func saveWithinBudget() async throws {
        let prefs = StorePreferences(store: store)
        let keys = Dictionary(uniqueKeysWithValues: (0..<32).map { ("key\($0)", "value-\($0)") })
        var p = SuitePreferences(perApp: ["photo": keys])
        _ = try await suiteMeasure("preferences.save", runs: 50, budget: suiteBudget(device: 2)) { _ in
            p = try await prefs.save(p)
        }
        #expect(p.revision == 50)
        #expect(try onDisk().revision == 50 && onDisk().value?.perApp == ["photo": keys])
    }
}
