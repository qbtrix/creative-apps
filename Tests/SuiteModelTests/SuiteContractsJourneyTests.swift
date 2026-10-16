// SuiteContractsJourneyTests.swift: the suite-contracts Model journey
// (packet, Journey steps). One person's day, walked on SuiteServices.fake and
// then on recents in a temporary FileStore: seed weekOfWork, note Logo.design,
// hand it to Design, remove Cards.design, and two racing store writers.
import Foundation
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(1))) struct SuiteContractsJourneyTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let documents = "/tmp/Documents"

    private func seeded() throws -> RecentsList {
        try #require(SuiteFixtures.store("weekOfWork", documents: documents, now: now)).recents
    }

    private func tempStore() -> FileStore {
        FileStore(folder: FileManager.default.temporaryDirectory.appendingPathComponent("SuiteJourney-\(UUID().uuidString)").path)
    }

    /// Steps 1, 2 and 4 on one RecentWork; returns Logo.design's ref.
    private func walkRecents(_ recents: any RecentWork) async throws -> SuiteDocumentRef {
        var changes = await recents.changes().makeAsyncIterator()
        // 1. weekOfWork: 8 items newest first, each with thumbnails/<fileKey>.png.
        let start = try await recents.list()
        #expect(start.items.count == 8)
        #expect(start.items.map(\.lastUsed) == start.items.map(\.lastUsed).sorted(by: >))
        for item in start.items { #expect(item.thumbnail == "thumbnails/\(SuiteDocumentRef.fileKey(item.ref.fileID)).png") }
        // 2. Logo.design opened now moves to the top, still 8.
        let logo = try #require(start.items.first { $0.ref.displayName == "Logo.design" }).ref
        try await recents.note(logo, event: .opened, at: now + 3600, thumbnail: nil)
        let noted = try await recents.list()
        #expect(noted.items.first?.ref == logo && noted.items.count == 8)
        // 4. Remove Cards.design: 7 items, and changes() yielded once per write.
        let cards = try #require(noted.items.first { $0.ref.displayName == "Cards.design" }).ref
        try await recents.remove(fileID: cards.fileID)
        let removed = try await recents.list()
        #expect(removed.items.count == 7 && !removed.items.contains { $0.ref == cards })
        let first = await changes.next(), second = await changes.next()
        #expect([first, second] == [start.revision + 1, start.revision + 2])
        return logo
    }

    @Test func aDayOnTheFakeServices() async throws {
        let services = SuiteServices.fake(recents: try seeded())
        let logo = try await walkRecents(services.recents)
        // 3. An .open hand-off for Logo.design: Design runs; the id is a UUID and decodes back equal.
        let handOff = HandOff(id: HandOff.newID(), from: .launcher, to: .design, verb: .open, documents: [logo], createdAt: now)
        #expect(await services.switching.runState(of: .design) == .notRunning)
        let receipt = try await services.sending.send(handOff)
        #expect(receipt.app == .design && !receipt.wasRunning)
        #expect(await services.switching.runState(of: .design) == .running(windows: 1))
        #expect(UUID(uuidString: handOff.id) != nil && handOff.id == handOff.id.lowercased())
        #expect(try HandOffCodec.decode(HandOffCodec.encode(handOff)) == handOff)
        let received = try await services.receiving.receive(HandOffCodec.encode(handOff), now: now + 1)
        #expect(received.id == handOff.id && received.documents == [logo])
    }

    @Test func theSameDayOnATemporaryStore() async throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(atPath: store.folder) }
        try store.write("recents.json", try seeded(), expecting: 0)
        _ = try await walkRecents(StoreRecents(store: store))
    }

    @Test func twoStoreWritersRaceAndBothItemsLand() throws {
        // 5. Two writers on recents.json, one stale: it gets staleRevision, re-reads, merges, and both items are present.
        let folder = tempStore().folder
        defer { try? FileManager.default.removeItem(atPath: folder) }
        let a = FileStore(folder: folder), b = FileStore(folder: folder)
        try a.write("recents.json", try seeded(), expecting: 0)
        func item(_ name: String, _ at: Double) -> RecentItem {
            let path = documents + "/" + name
            return RecentItem(ref: SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .design,
                                                    type: .designDocument, displayName: name), lastUsed: now + at, thumbnail: nil)
        }
        let (readA, revA) = try a.read("recents.json", as: RecentsList.self)
        let (readB, revB) = try b.read("recents.json", as: RecentsList.self)
        var mineA = try #require(readA), mineB = try #require(readB)
        mineB.note(item("Poster.design", 60))
        try b.write("recents.json", mineB, expecting: revB)
        mineA.note(item("Badge.design", 120))
        #expect(throws: SuiteError.staleRevision) { try a.write("recents.json", mineA, expecting: revA) }
        let (current, revNow) = try a.read("recents.json", as: RecentsList.self)
        try a.write("recents.json", try #require(current).merging(mineA), expecting: revNow)
        let names = try #require(try b.read("recents.json", as: RecentsList.self).value).items.map(\.ref.displayName)
        #expect(names.prefix(2) == ["Badge.design", "Poster.design"])
        #expect(names.count == 10)
    }
}
