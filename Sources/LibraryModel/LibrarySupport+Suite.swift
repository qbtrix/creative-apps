// LibrarySupport+Suite.swift: where Library's catalog lives (adopt-kernel-autosave
// AK-5 stub, AK-6 body). The catalog's folder is `-LibraryCatalogDir` when the
// launch names one, else Library's folder under the suite root
// (`SuiteLocations.appFolder("Library")`, which `-SuiteSupportDir` moves).
// `legacyCatalog` is where an earlier build kept it, under Application Support,
// for the move-once rule (`LegacySupport.plan`). Pure strings, Linux-safe.
// AK-5: the stub still answers the earlier place; AK-6 moves it under the root.
import SuiteModel

/// Library's folders under the suite's support root.
public enum LibrarySupport {
    /// `-LibraryCatalogDir` when given, else `appFolder("Library")`.
    public static func catalogFolder(arguments: [String], home: String) -> String {
        if let directory = LibraryLaunch(arguments: arguments).catalogDir, !directory.isEmpty {
            return directory
        }
        return SuiteLocations.legacyFolder("Library", home: home)
    }

    /// The catalog an earlier build wrote, relative to Application Support.
    public static let legacyCatalog = "Library/catalog.json"
}
