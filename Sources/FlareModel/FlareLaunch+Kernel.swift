// FlareLaunch+Kernel.swift: Flare's adapter onto SuiteModel's FixtureSeeder for `-SuiteFixture <name>` on a
// Flare launch (file-flow FLJ1, #4604). The launcher seeds the suite store with a journey fixture before its first read; a journey that launches Flare
// alone passes the same flags, so Flare seeds the store the same way before its documents bridge first reads
// the shared recents. Documents come from `-SuiteFixtureDocuments` and land in the support folder's Documents,
// as on the launcher. No `-SuiteFixture`, or one that can't be seeded, leaves the store as it was. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

extension FlareLaunch {
    /// The `-SuiteFixture` name in `arguments`, or nil.
    public static func suiteFixture(in arguments: [String]) -> String? { value(after: "-SuiteFixture", in: arguments) }

    /// Seeds the suite store under `support` with the `-SuiteFixture` the arguments name; false when none was seeded.
    @discardableResult
    public static func seedSuiteFixture(arguments: [String], support: String, now: Date = Date()) -> Bool {
        guard let name = suiteFixture(in: arguments) else { return false }
        do {
            try FixtureSeeder.seed(name, into: FileStore(folder: support),
                                   documentsFrom: value(after: "-SuiteFixtureDocuments", in: arguments) ?? "",
                                   documentsTo: support + "/Documents", now: now)
            return true
        } catch {
            return false
        }
    }

    /// The non-empty argument after `flag`, if any.
    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count,
              !arguments[index + 1].isEmpty else { return nil }
        return arguments[index + 1]
    }
}
