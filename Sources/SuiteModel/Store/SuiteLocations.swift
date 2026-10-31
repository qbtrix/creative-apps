// SuiteLocations.swift: where the suite store lives (docs/blueprints/suite.md,
// 2.6). `~/Library/Application Support/AfterGlow/` unless the launch
// arguments name another folder with `-SuiteSupportDir <path>` (journeys and
// tests). Arguments that name a test bundle (`*.xctest`, how `swift test`
// starts a test process) never get the real folder: they get one temporary
// folder per process, so no test writes into a user's store (#5221). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Finds the suite store's support folder.
public enum SuiteLocations {
    /// The flag a journey passes to point every process at a temporary store.
    public static let supportDirFlag = "-SuiteSupportDir"

    /// The support folder: the path after `-SuiteSupportDir` when the
    /// arguments carry a non-empty one, else AfterGlow's folder under `home`.
    public static func supportFolder(arguments: [String], home: String) -> String {
        if let flag = arguments.firstIndex(of: supportDirFlag) {
            let next = arguments.index(after: flag)
            if next < arguments.endIndex, !arguments[next].isEmpty {
                return arguments[next]
            }
        }
        if arguments.contains(where: { $0.hasSuffix(".xctest") || $0.contains(".xctest/") }) { return testProcessFolder }
        let base = home.hasSuffix("/") ? String(home.dropLast()) : home
        return base + "/Library/Application Support/AfterGlow"
    }

    /// The support folder of a test process that names none: one per process, in the temporary directory.
    public static let testProcessFolder: String = {
        let tmp = FileManager.default.temporaryDirectory.path(percentEncoded: false)
        return (tmp.hasSuffix("/") ? tmp : tmp + "/") + "AfterGlowTests-\(ProcessInfo.processInfo.processIdentifier)"
    }()
}

/// One folder per app under the suite root, and where earlier builds kept an
/// app's files (adopt-kernel-autosave AK-2). Every app's store is its own
/// folder, so no app reads (or drops) another app's files. App names are the
/// suite's ids, so they need no escaping.
extension SuiteLocations {
    /// `<supportFolder>/<app>`: one folder per app under the suite root ("Photo", "Flare", "Library", ...).
    public static func appFolder(_ app: String, arguments: [String], home: String) -> String {
        supportFolder(arguments: arguments, home: home) + "/" + app
    }

    /// Where an earlier build kept this app's files: `<home>/Library/Application Support/<legacy>`.
    public static func legacyFolder(_ legacy: String, home: String) -> String {
        let base = home.hasSuffix("/") ? String(home.dropLast()) : home
        return base + "/Library/Application Support/" + legacy
    }
}
