// TestIsolationTests.swift: no store a test can reach writes into the user's
// real ~/Library/Application Support. Each store is built the way the tests
// build it (Photo's `.live` recovery, a default CatalogStore, the launcher's
// support folder) before the defaults change, then TestDefaults registers a
// fresh folder, and each store must write inside it. A store that fixed its
// folder when it was built, or that ignores the registered default, fails here
// whatever ran before it. The process's own folder is registered again after.
// macOS only.
#if canImport(AppKit)
import Foundation
import PhotoModel
import Testing

@testable import AfterGlowApp
@testable import LibraryApp
@testable import PhotoModel

@MainActor
@Suite struct TestIsolationTests {
    @Test func everyStoreWritesInTheRegisteredFolder() throws {
        let photo = try #require(PhotoServices.live.recovery as? LiveRecovery, "Photo's live recovery isn't LiveRecovery")
        let catalog = CatalogStore()
        _ = TestDefaults.registered
        let probe = FileManager.default.temporaryDirectory.appending(path: "isolation-\(UUID().uuidString)")
        TestDefaults.register(in: probe)
        defer { TestDefaults.register(in: TestDefaults.folder) }
        let root = probe.standardizedFileURL.path(percentEncoded: false)
        let folders = [
            ("Photo recovery", photo.directory),
            ("Library catalog", catalog.folder),
            ("suite support", URL(fileURLWithPath: LauncherServices.support)),
        ]
        for (name, folder) in folders {
            let path = folder.standardizedFileURL.path(percentEncoded: false)
            #expect(path.hasPrefix(root), "\(name) ignores the registered folder and writes to \(path)")
        }
    }
}
#endif
