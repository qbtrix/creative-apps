// TestDefaults.swift: the defaults every store and window in this test process
// reads, registered before the first hosted window, so the stores tests write
// through stay out of the user's real ~/Library/Application Support
// (TestIsolationTests checks they follow it). A windowless test that wrote
// through a default store before any window was hosted would still miss it.
// `ApplePersistenceIgnoreState` is the journeys' launch flag: with it a hosted
// window's `.autosaveRecovery` gets no folder (Flare's FlareAutosaveAdapter,
// Design's history area), so it neither writes recovery copies after an edit
// nor offers a stale one as an alert sheet over every later window.
// `PhotoRecoveryDir`, `LibraryCatalogDir` and `SuiteSupportDir` point Photo's
// recovery, Library's catalog and the suite store at one temporary folder per
// test process; those stores read their default at each use. One folder per
// process, not per test: a Photo autosave one test leaves there can still be
// offered by a later Photo window in the same run. Registered, never set: the
// registration domain lives only in this process and leaves nothing in the
// helper's defaults on disk. The windows read the ignore-state default once per
// process (a static), so each host that can draw one (RenderBudgetWindow,
// `render(_:scheme:)`) touches `registered` before it builds its window.
import Foundation

enum TestDefaults {
    /// This process's stand-in for Application Support.
    static let folder = FileManager.default.temporaryDirectory
        .appending(path: "AppSnapshotTests-\(ProcessInfo.processInfo.processIdentifier)", directoryHint: .isDirectory)

    static let registered: Void = { register(in: folder) }()

    /// Registers the defaults with `root` standing in for Application Support.
    static func register(in root: URL) {
        UserDefaults.standard.register(defaults: [
            "ApplePersistenceIgnoreState": true,
            "PhotoRecoveryDir": root.appending(path: "Photo").path(percentEncoded: false),
            "LibraryCatalogDir": root.appending(path: "Library").path(percentEncoded: false),
            "SuiteSupportDir": root.appending(path: "AfterGlow").path(percentEncoded: false),
        ])
    }
}
