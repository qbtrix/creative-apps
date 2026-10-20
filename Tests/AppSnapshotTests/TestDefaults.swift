// TestDefaults.swift: the defaults every store and window in this test process
// reads, registered once, so nothing a test does lands in the user's real
// ~/Library/Application Support (TestIsolationTests holds it).
// `ApplePersistenceIgnoreState` is the journeys' launch flag: with it
// FlareRecovery keeps no recovery file, so a hosted FlareWindow neither writes
// Flare/Recovery.flare nor offers a stale one as an alert sheet over every
// later Flare window. `PhotoRecoveryDir`, `LibraryCatalogDir` and
// `SuiteSupportDir` point Photo's recovery, Library's catalog and the suite
// store at one temporary folder per test process; those stores read their
// default at each use. One folder per process, not per test: a Photo autosave
// one test leaves there can still be offered by a later Photo window in the
// same run. Registered, never set: the registration domain lives only in this
// process and leaves nothing in the helper's defaults on disk. FlareRecovery
// reads its default once per process, so each host that can draw a FlareWindow
// (RenderBudgetWindow, `render(_:scheme:)`) touches `registered` first.
import Foundation

enum TestDefaults {
    /// This process's stand-in for Application Support.
    static let folder = FileManager.default.temporaryDirectory
        .appending(path: "AppSnapshotTests-\(ProcessInfo.processInfo.processIdentifier)", directoryHint: .isDirectory)

    static let registered: Void = {
        UserDefaults.standard.register(defaults: [
            "ApplePersistenceIgnoreState": true,
            "PhotoRecoveryDir": folder.appending(path: "Photo/Recovery").path(percentEncoded: false),
            "LibraryCatalogDir": folder.appending(path: "Library").path(percentEncoded: false),
            "SuiteSupportDir": folder.appending(path: "AfterGlow").path(percentEncoded: false),
        ])
    }()
}
