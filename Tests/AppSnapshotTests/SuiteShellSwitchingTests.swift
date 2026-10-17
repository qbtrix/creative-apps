// SuiteShellSwitchingTests.swift: the live switching pieces on macOS (SW-3a;
// blueprint 2.3, shell-apps and shell-store-watch). A store change posted by
// one process reaches an observer; a hidden app reads as missing, not as not
// running; a store behind recents sees another instance's write after the post.
import Foundation
import SuiteModel
import SuiteShell
import Testing

@Suite struct SuiteShellSwitchingTests {
    @Test func aPostedStoreChangeReachesAnObserverWithinASecond() async {
        let file = "switching-test-\(UUID().uuidString).json"
        let (heard, hear) = AsyncStream<Bool>.makeStream()
        StoreWatcher.observe(file) { hear.yield(true) }
        StoreWatcher.post(file)
        let arrived = await withTaskGroup(of: Bool.self) { group in
            group.addTask { for await _ in heard { return true }; return false }
            group.addTask { try? await Task.sleep(for: .seconds(1)); return false }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        #expect(arrived)
    }

    @Test func aHiddenAppReadsAsMissingNotAsNotRunning() async {
        let launcher = AppLauncher(bundle: "/nonexistent/AfterGlow.app", arguments: ["-SuiteHideApp", "halo"])
        #expect(await launcher.runState(of: .halo) == .missing)
    }

    @Test func aStoreBehindRecentsSeesAnotherInstancesWriteAfterThePost() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwitchingRecents-\(UUID().uuidString)").path
        let store = FileStore(folder: folder)
        let reader = StoreRecents(store: store)
        let writer = StoreRecents(store: store)
        let ref = SuiteDocumentRef(path: "/d/Logo.design", fileID: "logo", app: .design,
                                   type: .designDocument, displayName: "Logo")
        var changes = await reader.changes().makeAsyncIterator()
        try await writer.note(ref, event: .opened, at: Date(), thumbnail: nil)
        await reader.externalChange()
        #expect(await changes.next() == 1)
        #expect(try await reader.list().items.map(\.ref.fileID) == ["logo"])
    }
}
