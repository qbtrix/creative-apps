// FixtureSeederTests.swift: seeding a journey fixture writes the three store
// files, copies the fixture documents and files their thumbnails by fileKey
// (SC-4c; packet correction 5).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct FixtureSeederTests {
    private struct Folders {
        let store: FileStore
        let from: String
        let to: String
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// A fresh support folder and a source folder holding every weekOfWork
    /// document (except `skipping`) and a thumbnail named after each.
    private func makeFolders(skipping: Set<String> = []) throws -> Folders {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FixtureSeederTests-\(UUID().uuidString)").path
        let from = root + "/source"
        try FileManager.default.createDirectory(atPath: from + "/thumbnails", withIntermediateDirectories: true)
        for (file, _, _) in SuiteFixtures.weekOfWorkFiles where !skipping.contains(file) {
            try Data("doc \(file)".utf8).write(to: URL(fileURLWithPath: from + "/" + file))
            try Data("png \(file)".utf8).write(to: URL(fileURLWithPath: from + "/thumbnails/" + file + ".png"))
        }
        return Folders(store: FileStore(folder: root + "/support"), from: from, to: root + "/support/Documents")
    }

    private func documents(in folder: String) -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        return Set(names.filter { !$0.hasPrefix(".") })
    }

    private func thumbnailKey(_ folders: Folders, _ file: String) -> String {
        SuiteDocumentRef.fileKey(SuiteDocumentRef.fileID(forPath: folders.to + "/" + file))
    }

    @Test func weekOfWorkWritesStoreFilesDocumentsAndThumbnailsByFileKey() throws {
        let f = try makeFolders()
        try FixtureSeeder.seed("weekOfWork", into: f.store, documentsFrom: f.from, documentsTo: f.to, now: now)

        let expected = SuiteFixtures.store("weekOfWork", documents: f.to, now: now)
        #expect(try f.store.read("recents.json", as: RecentsList.self).value == expected?.recents)
        #expect(try f.store.read("assets/index.json", as: AssetIndex.self).value == expected?.assets)
        #expect(try f.store.read("preferences.json", as: SuitePreferences.self).value == expected?.preferences)

        #expect(documents(in: f.to) == Set(SuiteFixtures.weekOfWorkFiles.map(\.0)))
        for (file, _, _) in SuiteFixtures.weekOfWorkFiles {
            #expect(try f.store.readData("Documents/" + file) == Data("doc \(file)".utf8))
            let thumb = "thumbnails/\(thumbnailKey(f, file)).png"
            #expect(try f.store.readData(thumb) == Data("png \(file)".utf8))
            #expect(try f.store.readData("thumbnails/\(file).png") == nil)
        }
        let thumbs = documents(in: f.store.folder + "/thumbnails").filter { $0.hasSuffix(".png") }
        #expect(thumbs.count == 8)
        // Every recents card points at a thumbnail that exists.
        for item in expected?.recents.items ?? [] {
            #expect(try f.store.readData(item.thumbnail ?? "none") != nil)
        }
    }

    @Test func missingSkipsTheCardsDocument() throws {
        let f = try makeFolders()
        try FixtureSeeder.seed("missing", into: f.store, documentsFrom: f.from, documentsTo: f.to, now: now)
        let docs = documents(in: f.to)
        #expect(docs.count == 7)
        #expect(!docs.contains("Cards.design"))
        #expect(docs.contains("Logo.design"))
        #expect(try f.store.read("recents.json", as: RecentsList.self).value?.items.count == 8)
    }

    @Test func anAbsentSourceIsSkippedAndTheSeedStillSucceeds() throws {
        let f = try makeFolders(skipping: ["Intro.halo"])
        try FixtureSeeder.seed("weekOfWork", into: f.store, documentsFrom: f.from, documentsTo: f.to, now: now)
        let docs = documents(in: f.to)
        #expect(docs.count == 7)
        #expect(!docs.contains("Intro.halo"))
        #expect(try f.store.readData("thumbnails/\(thumbnailKey(f, "Intro.halo")).png") == nil)
    }

    @Test func roundTripCopiesDocumentsWithEmptyRecents() throws {
        let f = try makeFolders()
        try FixtureSeeder.seed("roundTrip", into: f.store, documentsFrom: f.from, documentsTo: f.to, now: now)
        #expect(documents(in: f.to).count == 8)
        #expect(try f.store.read("recents.json", as: RecentsList.self).value?.items.isEmpty == true)
    }

    @Test func emptyCopiesNoDocuments() throws {
        let f = try makeFolders()
        try FixtureSeeder.seed("empty", into: f.store, documentsFrom: f.from, documentsTo: f.to, now: now)
        #expect(documents(in: f.to).isEmpty)
        #expect(try f.store.read("preferences.json", as: SuitePreferences.self).revision == 1)
    }

    @Test func reseedingOverwritesTheStoreFiles() throws {
        let f = try makeFolders()
        try FixtureSeeder.seed("weekOfWork", into: f.store, documentsFrom: f.from, documentsTo: f.to, now: now)
        try FixtureSeeder.seed("empty", into: f.store, documentsFrom: f.from, documentsTo: f.to, now: now)
        #expect(try f.store.read("recents.json", as: RecentsList.self).value?.items.isEmpty == true)
    }

    @Test func anUnknownNameThrowsNoFixtureNamed() throws {
        let f = try makeFolders()
        #expect(throws: SuiteError.notAvailable("No fixture named nope.")) {
            try FixtureSeeder.seed("nope", into: f.store, documentsFrom: f.from, documentsTo: f.to, now: now)
        }
        #expect(try f.store.readData("recents.json") == nil)
    }
}
