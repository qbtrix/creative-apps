// LibrarySupport+Suite.swift: where Library's catalog lives (adopt-kernel-autosave
// AK-5 stub, AK-6 body). The catalog's folder is `-LibraryCatalogDir` when the
// launch names one, else Library's folder under the suite root
// (`SuiteLocations.appFolder("Library")`, which `-SuiteSupportDir` moves).
// `legacyCatalog` is where an earlier build kept it, under Application Support,
// for the move-once rule (`LegacySupport.plan`). Pure strings, Linux-safe.
import SuiteModel

/// Library's folders under the suite's support root.
public enum LibrarySupport {
    /// `-LibraryCatalogDir` when given, else `appFolder("Library")`.
    public static func catalogFolder(arguments: [String], home: String) -> String {
        if let directory = LibraryLaunch(arguments: arguments).catalogDir, !directory.isEmpty {
            return directory
        }
        return SuiteLocations.appFolder("Library", arguments: arguments, home: home)
    }

    /// The catalog an earlier build wrote, relative to Application Support.
    public static let legacyCatalog = "Library/catalog.json"

    /// The catalog's file name in its folder.
    public static let catalogName = "catalog.json"

    /// What the store does with the earlier build's catalog before its first
    /// load. Only a launch on the real root moves it: a launch on another
    /// folder (`-SuiteSupportDir` or `-LibraryCatalogDir`, as journeys and
    /// tests pass) never touches the person's real files. Never overwrites.
    public static func legacyCatalogStep(
        arguments: [String], home: String, exists: (String) -> Bool
    ) -> LegacySupport.Step {
        let folder = catalogFolder(arguments: arguments, home: home)
        guard folder == catalogFolder(arguments: [], home: home) else { return .nothing }
        return LegacySupport.plan(
            old: SuiteLocations.legacyFolder(legacyCatalog, home: home),
            new: folder + "/" + catalogName, exists: exists)
    }
}
