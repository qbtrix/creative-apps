// StoreHardeningTests.swift: the suite store survives what another process
// or a person leaves on disk (finding issues #1459, #1465, #1466, #1468,
// #1487, #1488):
// errors name what broke in plain words, a damaged file is moved aside
// instead of blocking every write, a huge revision never overflows, and a
// name can't leave the support folder. A fresh temp folder per test.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(1))) struct StoreHardeningTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeRoot() -> String {
        FileManager.default.temporaryDirectory.appendingPathComponent("StoreHardeningTests-\(UUID().uuidString)").path
    }

    private func put(_ store: FileStore, _ name: String, _ text: String) throws {
        let path = store.folder + "/" + name
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: path).deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        #expect(FileManager.default.createFile(atPath: path, contents: Data(text.utf8)))
    }

    private func files(_ store: FileStore) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: store.folder)) ?? []
    }

    private func ref(_ name: String) -> SuiteDocumentRef {
        let path = "/tmp/Documents/" + name
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .design,
                                type: .designDocument, displayName: name)
    }

    // MARK: #1459 plain messages

    @Test func storeErrorsNameNoFileOrPathAndAReadSaysRead() throws {
        let store = FileStore(folder: makeRoot())
        try put(store, "recents.json", "garbage")
        do {
            _ = try store.read("recents.json", as: [String].self)
            Issue.record("garbage decoded")
        } catch {
            #expect(!error.message.contains(".json") && !error.message.contains("/"))
        }
        // A folder where the file should be: it exists but has no bytes to read.
        try FileManager.default.createDirectory(atPath: store.folder + "/preferences.json", withIntermediateDirectories: true)
        do {
            _ = try store.readData("preferences.json")
            Issue.record("a folder read as data")
        } catch {
            #expect(error == .readFailed("your suite settings"))
            #expect(!error.message.contains(".json") && !error.message.contains("/"))
            #expect(!error.message.hasPrefix("Couldn't save"))
        }
    }

    // #1488: each file kind has its own plain words, and an unknown name
    // falls back to "a suite file".
    @Test(arguments: [("handoffs/x.aghandoff", "the message from another app"),
                      ("assets/index.json", "your shared assets list"),
                      ("thumbnails/x.png", "a thumbnail"),
                      ("other.json", "a suite file")])
    func aStoreErrorNamesEachFileKindInPlainWords(name: String, subject: String) throws {
        let store = FileStore(folder: makeRoot())
        // A folder where the file should be: it exists but has no bytes to read.
        try FileManager.default.createDirectory(atPath: store.folder + "/" + name, withIntermediateDirectories: true)
        #expect(throws: SuiteError.readFailed(subject)) { try store.readData(name) }
    }

    // MARK: #1465 a damaged file never blocks writes

    @Test(arguments: ["", #"{"revision":3,"value":{"revision":3,"items":[{"ref":{"app":"futureApp"}}]}}"#])
    func aDamagedRecentsFileIsMovedAsideAndNoteStillLands(damaged: String) async throws {
        let store = FileStore(folder: makeRoot())
        try put(store, "recents.json", damaged)
        let recents = StoreRecents(store: store)
        try await recents.note(ref("Logo.design"), event: .opened, at: now, thumbnail: nil)
        let list = try await recents.list()
        #expect(list.items.map(\.ref.displayName) == ["Logo.design"])
        #expect(list.revision == 1)
        let aside = files(store).filter { $0.hasPrefix("recents.json.damaged-") }
        #expect(aside.count == 1)
        #expect(FileManager.default.contents(atPath: store.folder + "/" + (aside.first ?? "")) == Data(damaged.utf8))
    }

    @Test func seedingOverADamagedRecentsFileSucceeds() throws {
        let root = makeRoot()
        let store = FileStore(folder: root + "/support")
        try put(store, "recents.json", "not json")
        try FixtureSeeder.seed("weekOfWork", into: store, documentsFrom: root + "/none",
                               documentsTo: root + "/support/Documents", now: now)
        let expected = SuiteFixtures.store("weekOfWork", documents: root + "/support/Documents", now: now)
        #expect(try store.read("recents.json", as: RecentsList.self).value == expected?.recents)
    }

    // MARK: #1466 no overflow on a huge revision

    @Test func aMaximalRevisionIsDamagedAndUpdateRecoversWithoutCrashing() throws {
        let store = FileStore(folder: makeRoot())
        try put(store, "recents.json", #"{"revision":9223372036854775807,"value":["a"]}"#)
        #expect(throws: SuiteError.self) { try store.read("recents.json", as: [String].self) }
        #expect(throws: SuiteError.self) { try store.write("recents.json", ["b"], expecting: Int.max) }
        let updated = try store.update("recents.json", empty: [String]()) { $0 + ["b"] }
        #expect(updated.value == ["b"] && updated.revision == 1)
        try put(store, "preferences.json", #"{"revision":-4,"value":["a"]}"#)
        #expect(throws: SuiteError.self) { try store.read("preferences.json", as: [String].self) }
    }

    @Test func aMaximalListRevisionInsideRecentsNeverOverflows() async throws {
        let store = FileStore(folder: makeRoot())
        try store.write("recents.json", RecentsList(revision: Int.max), expecting: 0)
        let recents = StoreRecents(store: store)
        try await recents.note(ref("Logo.design"), event: .opened, at: now, thumbnail: nil)
        #expect(try await recents.list().items.count == 1)
    }

    // MARK: #1468 names stay inside the folder

    @Test(arguments: ["../escape.json", "/etc/hosts", "", "a/../../b", "./x", "a//b", "dir/"])
    func aNameThatLeavesTheFolderIsDamaged(name: String) throws {
        let root = makeRoot()
        let store = FileStore(folder: root + "/support")
        // #1487: the error names what the file holds, never the raw name.
        let damaged = SuiteError.damaged("a suite file")
        #expect(throws: damaged) { try store.writeData(name, Data("x".utf8)) }
        #expect(throws: damaged) { try store.readData(name) }
        #expect(throws: damaged) { try store.update(name, empty: [String]()) { $0 } }
        #expect(!FileManager.default.fileExists(atPath: root + "/escape.json"))
        #expect(!FileManager.default.fileExists(atPath: root + "/escape.json.lock"))
    }

    @Test func anEscapingHandOffNameSaysWhatItHolds() {
        let store = FileStore(folder: makeRoot())
        #expect(throws: SuiteError.damaged("the message from another app")) { try store.readData("handoffs/../x") }
    }
}
