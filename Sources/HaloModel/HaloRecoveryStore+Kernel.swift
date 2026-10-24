// HaloRecoveryStore+Kernel.swift (autosave-history HA-7b): an adapter onto SuiteModel's
// RecoveryFolder and SuiteLocations, where a Halo window's autosave keeps its recovery copies, the
// folder DesignRecoveryStore picks for Design. `-SuiteSupportDir <path>` puts them under
// `<path>/Halo/Recovery/` as `<window>.halo` (the journeys pass a temp folder). A launch that
// ignores restored state, by `-ApplePersistenceIgnoreState YES` in argv or the caller's
// `ignoringState` (the app's user default, which a test host registers), keeps none unless it
// names a support folder, so no journey or hosted test leaves a copy for the next to be offered.
// Any other launch writes under the suite root (`SuiteLocations.appFolder`). Linux-safe.
import SuiteModel

public enum HaloRecoveryStore {
    /// The recovery folder for a launch with `arguments` and home folder `home`; nil keeps no copies.
    public static func folder(arguments: [String], home: String, ignoringState: Bool = false) -> RecoveryFolder? {
        folderPath(arguments: arguments, home: home, ignoringState: ignoringState)
            .map { RecoveryFolder(store: FileStore(folder: $0), ext: "halo") }
    }

    /// The app folder the copies go under (`<support>/Halo`); nil keeps no copies.
    static func folderPath(arguments: [String], home: String, ignoringState: Bool = false) -> String? {
        let named = !(argument(after: SuiteLocations.supportDirFlag, in: arguments) ?? "").isEmpty
        let ignored = ignoringState || ["yes", "true", "1"].contains(
            (argument(after: "-ApplePersistenceIgnoreState", in: arguments) ?? "").lowercased())
        return ignored && !named ? nil : SuiteLocations.appFolder("Halo", arguments: arguments, home: home)
    }

    /// The argument right after `flag`; nil without the flag or anything after it.
    private static func argument(after flag: String, in arguments: [String]) -> String? {
        arguments.firstIndex(of: flag).flatMap { index in
            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        }
    }
}
