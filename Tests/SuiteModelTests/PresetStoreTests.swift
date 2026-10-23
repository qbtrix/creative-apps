// PresetStoreTests.swift: the preset store (adjust-everywhere AJ-2, AJ-7).
// The PresetStore checks hold the behaviour AJ-7 builds and stay disabled
// by name until it lands; the FakePresetStore checks run now, so the fake
// every adopter's tests use already keeps the same rules. A fresh temp
// folder per test.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(1))) struct PresetStoreTests {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("PresetStoreTests-\(UUID().uuidString)").path

    func look(_ id: String, _ name: String, kind: String = "look") -> PresetRecord {
        PresetRecord(id: id, name: name, kind: kind, payload: Data(id.utf8))
    }

    // MARK: PresetStore (AJ-7)

    @Test(.disabled("waits on AJ-7")) func saveThenListRoundTripsAcrossARelaunch() throws {
        try PresetStore(folder: folder).save(look("a", "Mine"))
        #expect(PresetStore(folder: folder).list(kind: "look") == [look("a", "Mine")])
    }

    @Test(.disabled("waits on AJ-7")) func deleteRemoves() throws {
        let store = PresetStore(folder: folder)
        try store.save(look("a", "Mine"))
        try store.save(look("b", "Other"))
        try store.delete(id: "a", kind: "look")
        #expect(store.list(kind: "look") == [look("b", "Other")])
    }

    @Test(.disabled("waits on AJ-7")) func listFiltersByKind() throws {
        let store = PresetStore(folder: folder)
        try store.save(look("a", "Mine"))
        try store.save(look("b", "Brush", kind: "brush"))
        #expect(store.list(kind: "look") == [look("a", "Mine")])
        #expect(store.list(kind: "brush") == [look("b", "Brush", kind: "brush")])
    }

    @Test(.disabled("waits on AJ-7")) func aTakenNameIgnoringCaseIsRefused() throws {
        let store = PresetStore(folder: folder)
        try store.save(look("a", "Mine"))
        #expect(throws: SuiteError.self) { try store.save(look("b", "mine")) }
        #expect(store.list(kind: "look") == [look("a", "Mine")])
    }

    @Test(.disabled("waits on AJ-7")) func aSaveThatCannotWriteThrows() throws {
        // A regular file where the folder should be: nothing can be written under it.
        #expect(FileManager.default.createFile(atPath: folder, contents: Data()))
        #expect(throws: SuiteError.self) { try PresetStore(folder: folder).save(look("a", "Mine")) }
    }

    // MARK: FakePresetStore (runs now)

    @Test func fakeSaveListAndDelete() throws {
        let store = FakePresetStore()
        try store.save(look("a", "Mine"))
        try store.save(look("b", "Brush", kind: "brush"))
        #expect(store.list(kind: "look") == [look("a", "Mine")])
        try store.delete(id: "a", kind: "look")
        #expect(store.list(kind: "look").isEmpty)
        #expect(store.list(kind: "brush") == [look("b", "Brush", kind: "brush")])
    }

    @Test func fakeRefusesATakenNameIgnoringCase() throws {
        let store = FakePresetStore([look("a", "Mine")])
        #expect(throws: SuiteError.self) { try store.save(look("b", "MINE")) }
        try store.save(look("a", "mine"))   // the same preset renamed is not a clash
        #expect(store.list(kind: "look") == [look("a", "mine")])
    }

    @Test func fakeUnavailableThrowsItsSentence() {
        let store = FakePresetStore(unavailable: "Saved looks aren't available yet.")
        #expect(throws: SuiteError.notAvailable("Saved looks aren't available yet.")) { try store.save(look("a", "Mine")) }
        #expect(store.list(kind: "look").isEmpty)
    }

    @Test func storeStubRefusesUntilAJ7() {
        let store = PresetStore(folder: folder)
        #expect(throws: SuiteError.self) { try store.save(look("a", "Mine")) }
        #expect(store.list(kind: "look").isEmpty)
        #expect(PresetStore.file == "presets/looks.json")
    }
}
