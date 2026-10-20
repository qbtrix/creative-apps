// TestIsolationTests.swift: no store a test can reach writes into the user's
// real ~/Library/Application Support. Each store is built the way the tests
// build it (Photo's `.live` recovery, a default CatalogStore, the launcher's
// support folder), then TestDefaults is registered, and the folder each one
// would write to must sit outside the user's Application Support: a store that
// fixed its folder when it was built, or that ignores the registered default,
// fails here. macOS only.
#if canImport(AppKit)
import Foundation
import PhotoModel
import Testing

@testable import AfterGlowApp
@testable import LibraryApp
@testable import PhotoModel

@MainActor
@Suite struct TestIsolationTests {
    @Test func everyStoreWritesOutsideTheUsersApplicationSupport() throws {
        let photo = try #require(PhotoServices.live.recovery as? LiveRecovery, "Photo's live recovery isn't LiveRecovery")
        let catalog = CatalogStore()
        _ = TestDefaults.registered
        let real = try #require(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)
            .standardizedFileURL.path(percentEncoded: false)
        let folders = [
            ("Photo recovery", photo.directory.standardizedFileURL.path(percentEncoded: false)),
            ("Library catalog", catalog.folder.standardizedFileURL.path(percentEncoded: false)),
            ("suite support", URL(fileURLWithPath: LauncherServices.support).standardizedFileURL.path(percentEncoded: false)),
        ]
        for (name, folder) in folders {
            #expect(!folder.hasPrefix(real), "\(name) writes into the user's \(folder)")
        }
    }
}
#endif
