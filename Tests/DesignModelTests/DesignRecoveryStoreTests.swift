// DesignRecoveryStoreTests.swift (design/autosave-history DA-7): where Design's autosave writes. A
// temp `-SuiteSupportDir` wins over the journeys' ignore-state flag, that flag alone (or the
// caller's `ignoringState`) keeps no copies, and a plain launch writes under the suite root's Design folder. A copy written to the
// folder comes back as the one left behind. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import SuiteModel
import Testing

@Suite struct DesignRecoveryStoreTests {
    static let ignore = ["-ApplePersistenceIgnoreState", "YES"]

    @Test func supportDirWinsOverIgnoredState() {
        let path = DesignRecoveryStore.folderPath(arguments: Self.ignore + ["-SuiteSupportDir", "/tmp/s"], home: "/Users/a")
        #expect(path == "/tmp/s/Design")
    }

    @Test func ignoredStateAloneKeepsNoCopies() {
        #expect(DesignRecoveryStore.folderPath(arguments: Self.ignore, home: "/Users/a") == nil)
        #expect(DesignRecoveryStore.folder(arguments: Self.ignore + ["-SuiteSupportDir", ""], home: "/Users/a") == nil)
    }

    /// The caller's ignore-state (the app's user default, which a test host registers) keeps none, as the flag does.
    @Test func ignoringStateKeepsNoCopiesUnlessASupportDirIsGiven() {
        #expect(DesignRecoveryStore.folder(arguments: [], home: "/Users/a", ignoringState: true) == nil)
        let path = DesignRecoveryStore.folderPath(arguments: ["-SuiteSupportDir", "/tmp/s"], home: "/Users/a", ignoringState: true)
        #expect(path == "/tmp/s/Design")
    }

    @Test func plainLaunchWritesUnderTheSuiteRoot() {
        let path = DesignRecoveryStore.folderPath(arguments: ["-ApplePersistenceIgnoreState", "NO"], home: "/Users/a")
        #expect(path == "/Users/a/Library/Application Support/AfterGlow/Design")
    }

    @Test func aWrittenCopyIsLeftBehind() throws {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent("design-recovery-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: support) }
        let folder = try #require(DesignRecoveryStore.folder(arguments: Self.ignore + ["-SuiteSupportDir", support.path], home: "/"))
        try folder.write(Data("card".utf8), window: "w1", name: "card.design", at: 10)
        let left = try folder.leftBehind()
        #expect(left.map(\.name) == ["card.design"])
        #expect(FileManager.default.fileExists(atPath: support.appendingPathComponent("Design/Recovery/w1.design").path))
    }
}
