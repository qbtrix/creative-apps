// LauncherRouter+Services.swift: the launcher's services (HM-2a): the live
// services over SuiteLocations' support folder, seeded first with
// `-SuiteFixture <name>` (documents from `-SuiteFixtureDocuments <path>`), so
// the home's first frame reads the fixture, with the launcher's updater.
import Foundation
import SuiteModel
import SuiteShell

enum LauncherServices {
    /// The support folder this process uses.
    static let support = SuiteLocations.supportFolder(
        arguments: ProcessInfo.processInfo.arguments, home: NSHomeDirectory())

    /// Built once, on first use: HomeWindow's model reads it before its first frame.
    static let shared = make(arguments: ProcessInfo.processInfo.arguments)

    /// The live services for `arguments`, seeding a `-SuiteFixture` first.
    static func make(arguments: [String], now: Date = Date()) -> SuiteServices {
        let support = SuiteLocations.supportFolder(arguments: arguments, home: NSHomeDirectory())
        if let name = value(after: "-SuiteFixture", in: arguments) {
            // A fixture that can't be seeded leaves the store as it was; its journey fails on what shows.
            try? FixtureSeeder.seed(
                name, into: FileStore(folder: support),
                documentsFrom: value(after: "-SuiteFixtureDocuments", in: arguments) ?? "",
                documentsTo: support + "/Documents", now: now)
        }
        return SuiteServices.live(support: support, app: .launcher, arguments: arguments)
            .with(updates: UpdateService.checker())
    }

    /// The non-empty argument after `flag`, if any.
    static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count,
              !arguments[index + 1].isEmpty else { return nil }
        return arguments[index + 1]
    }
}
