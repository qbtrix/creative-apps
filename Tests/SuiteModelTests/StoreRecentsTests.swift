// StoreRecentsTests.swift: the live RecentWork over FileStore (SC-5a).
// Each write lands in recents.json with a new revision, calls onWrite once
// and yields on changes(); a second instance on the same folder sees it
// after externalChange(). A fresh temp folder per test.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1))) struct StoreRecentsTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeStore() -> FileStore {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreRecentsTests-\(UUID().uuidString)").path
        return FileStore(folder: folder)
    }

    private func ref(_ name: String, _ app: SuiteApp = .design, _ type: SuiteTypeID = .designDocument) -> SuiteDocumentRef {
        let path = "/tmp/Documents/" + name
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: app, type: type, displayName: name)
    }

    /// What recents.json holds now, read straight from the store.
    private func onDisk(_ store: FileStore) throws -> (names: [String], revision: Int) {
        let read = try store.read("recents.json", as: RecentsList.self)
        return ((read.value?.items ?? []).map(\.ref.displayName), read.revision)
    }

    @Test func noteRemoveAndClearEachWriteANewRevision() async throws {
        let store = makeStore()
        let recents = StoreRecents(store: store)
        try await recents.note(ref("Logo.design"), event: .opened, at: now, thumbnail: "thumbnails/a.png")
        #expect(try onDisk(store) == (["Logo.design"], 1))
        try await recents.note(ref("Intro.halo", .halo, .haloProject), event: .saved, at: now + 60, thumbnail: nil)
        try await recents.note(ref("Cards.design"), event: .opened, at: now + 120, thumbnail: nil)
        #expect(try onDisk(store) == (["Cards.design", "Intro.halo", "Logo.design"], 3))
        try await recents.remove(fileID: ref("Cards.design").fileID)
        #expect(try onDisk(store) == (["Intro.halo", "Logo.design"], 4))
        try await recents.clear(app: .design)
        #expect(try onDisk(store) == (["Intro.halo"], 5))
        let list = try await recents.list()
        #expect(list.revision == 5)
        #expect(list.items.map(\.ref.displayName) == ["Intro.halo"])
    }

    @Test func reNoteKeepsTheThumbnail() async throws {
        let recents = StoreRecents(store: makeStore())
        try await recents.note(ref("Logo.design"), event: .opened, at: now, thumbnail: "thumbnails/a.png")
        try await recents.note(ref("Logo.design"), event: .saved, at: now + 60, thumbnail: nil)
        let items = try await recents.list().items
        #expect(items.count == 1)
        #expect(items.first?.thumbnail == "thumbnails/a.png")
        #expect(items.first?.lastUsed == now + 60)
    }

    @Test func onWriteIsCalledOncePerWrite() async throws {
        let calls = Mutex<[String]>([])
        let recents = StoreRecents(store: makeStore()) { name in calls.withLock { $0.append(name) } }
        try await recents.note(ref("Logo.design"), event: .opened, at: now, thumbnail: nil)
        try await recents.remove(fileID: ref("Logo.design").fileID)
        try await recents.clear(app: .flare)
        _ = try await recents.list()
        #expect(calls.withLock { $0 } == ["recents.json", "recents.json", "recents.json"])
    }

    @Test func changesYieldEachNewRevision() async throws {
        let recents = StoreRecents(store: makeStore())
        var changes = await recents.changes().makeAsyncIterator()
        try await recents.note(ref("Logo.design"), event: .opened, at: now, thumbnail: nil)
        #expect(await changes.next() == 1)
        try await recents.remove(fileID: ref("Logo.design").fileID)
        #expect(await changes.next() == 2)
    }

    @Test func twoInstancesSeeEachOthersWritesAfterExternalChange() async throws {
        let store = makeStore()
        let first = StoreRecents(store: store)
        let second = StoreRecents(store: FileStore(folder: store.folder))
        var secondChanges = await second.changes().makeAsyncIterator()
        var firstChanges = await first.changes().makeAsyncIterator()

        try await first.note(ref("Logo.design"), event: .opened, at: now, thumbnail: nil)
        #expect(await firstChanges.next() == 1)
        await second.externalChange()
        #expect(await secondChanges.next() == 1)
        #expect(try await second.list().items.map(\.ref.displayName) == ["Logo.design"])

        try await second.note(ref("Intro.halo", .halo, .haloProject), event: .opened, at: now + 60, thumbnail: nil)
        #expect(await secondChanges.next() == 2)
        await first.externalChange()
        #expect(await firstChanges.next() == 2)
        #expect(try await first.list().items.map(\.ref.displayName) == ["Intro.halo", "Logo.design"])
        #expect(try onDisk(store) == (["Intro.halo", "Logo.design"], 2))
    }

    @Test func externalChangeWithNothingNewYieldsNothing() async throws {
        let recents = StoreRecents(store: makeStore())
        var changes = await recents.changes().makeAsyncIterator()
        await recents.externalChange()
        try await recents.note(ref("Logo.design"), event: .opened, at: now, thumbnail: nil)
        await recents.externalChange()
        try await recents.remove(fileID: ref("Logo.design").fileID)
        #expect(await changes.next() == 1)
        #expect(await changes.next() == 2)
    }
}
