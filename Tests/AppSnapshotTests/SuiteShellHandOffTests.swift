// SuiteShellHandOffTests.swift: the macOS hand-off path (SW-3b; blueprint 2.6).
// A hand-off file a delegate receives reaches the host and is settled with the
// state the host ends in; an expired one never reaches the host; a document
// URL becomes an open hand-off to the host, and a file no suite type claims is dropped.
import Foundation
import SuiteModel
import SuiteShell
import Testing

@MainActor @Suite struct SuiteShellHandOffTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeStore() -> FileStore {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuiteShellHandOff-\(UUID().uuidString)").path
        return FileStore(folder: folder)
    }

    private func delegate(store: FileStore, host: FakeDocumentHost) -> SuiteAppDelegate {
        let delegate = SuiteAppDelegate()
        delegate.host = host
        delegate.receiver = StoreHandOffs(store: store, from: .launcher) { _, app async throws(SuiteError) -> SwitchReceipt in
            SwitchReceipt(app: app, wasRunning: true, requestedAt: 0)
        }
        delegate.app = .design
        return delegate
    }

    @Test func aReceivedHandOffReachesTheHostAndIsSettledWithItsState() async throws {
        let store = makeStore()
        let host = FakeDocumentHost(app: .design, verbs: [.open])
        let handOff = HandOff(id: HandOff.newID(), from: .launcher, to: .design, verb: .open, createdAt: now)
        try store.writeData("handoffs/\(handOff.id).aghandoff", try HandOffCodec.encode(handOff))
        let url = URL(fileURLWithPath: store.folder + "/handoffs/\(handOff.id).aghandoff")

        await delegate(store: store, host: host).handle(url)

        #expect(await host.accepted.map(\.id) == [handOff.id])
        let data = try #require(try store.readData("handoffs/\(handOff.id).aghandoff"))
        #expect(try HandOffCodec.decode(data).state == .returned)
    }

    @Test func aDocumentURLBecomesAnOpenHandOffToTheHost() async {
        let store = makeStore()
        let host = FakeDocumentHost(app: .design, verbs: [.open])
        let url = URL(fileURLWithPath: "/Users/someone/Logo.design")

        await delegate(store: store, host: host).handle(url)

        let accepted = await host.accepted
        #expect(accepted.map(\.verb) == [.open])
        #expect(accepted.first?.documents.map(\.displayName) == ["Logo.design"])
    }

    @Test func aFileNoSuiteTypeClaimsIsDropped() async {
        let store = makeStore()
        let host = FakeDocumentHost(app: .design, verbs: [.open])
        await delegate(store: store, host: host).handle(URL(fileURLWithPath: "/Users/someone/notes.xyz"))
        #expect(await host.accepted.isEmpty)
    }
}
