// SuiteLocations.swift: where the suite store lives (docs/blueprints/suite.md,
// 2.6). `~/Library/Application Support/AfterGlow/` unless the launch
// arguments name another folder with `-SuiteSupportDir <path>` (journeys and
// tests). Pure string logic, Linux-safe, Sendable.

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
        let base = home.hasSuffix("/") ? String(home.dropLast()) : home
        return base + "/Library/Application Support/AfterGlow"
    }
}
