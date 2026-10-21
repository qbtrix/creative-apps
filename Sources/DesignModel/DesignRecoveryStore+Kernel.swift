// DesignRecoveryStore+Kernel.swift (design/autosave-history DA-7): where a Design window's autosave writes
// its recovery copies. `-SuiteSupportDir <path>` puts them under `<path>/Design/Recovery/` (the
// journeys pass a temp folder); a launch that ignores restored state (the journeys'
// `-ApplePersistenceIgnoreState YES`) without one keeps none, so no journey leaves a copy for the
// next to be offered; any other launch writes under the suite root
// (`~/Library/Application Support/AfterGlow/Design/`, SuiteLocations.appFolder). Linux-safe.
import SuiteModel

public enum DesignRecoveryStore {
    /// The app's folder name under the suite root, and the raw copy's extension.
    static let app = "Design", ext = "design"

    /// The recovery folder for a launch with `arguments` and home folder `home`; nil keeps no copies.
    public static func folder(arguments: [String], home: String) -> RecoveryFolder? {
        guard let path = folderPath(arguments: arguments, home: home) else { return nil }
        return RecoveryFolder(store: FileStore(folder: path), ext: ext)
    }

    /// The folder `folder(arguments:home:)` writes under; nil keeps no copies.
    static func folderPath(arguments: [String], home: String) -> String? {
        if !hasSupportDir(arguments), ignoresState(arguments) { return nil }
        return SuiteLocations.appFolder(app, arguments: arguments, home: home)
    }

    /// Whether `arguments` carry `-SuiteSupportDir` with a non-empty path after it.
    static func hasSupportDir(_ arguments: [String]) -> Bool {
        value(after: SuiteLocations.supportDirFlag, in: arguments).map { !$0.isEmpty } ?? false
    }

    /// Whether `arguments` say `-ApplePersistenceIgnoreState YES` (or true, or 1).
    static func ignoresState(_ arguments: [String]) -> Bool {
        guard let flag = value(after: "-ApplePersistenceIgnoreState", in: arguments) else { return false }
        return ["yes", "true", "1"].contains(flag.lowercased())
    }

    /// The argument after `flag`; nil without the flag or a value after it.
    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let next = arguments.index(after: index)
        return next < arguments.endIndex ? arguments[next] : nil
    }
}
