// FlareSuiteFixtureTests.swift: a Flare launch with `-SuiteFixture` seeds the suite store the way the
// launcher does, so FLJ1's Open Recent lists weekOfWork's Bounce.flare and Title.flare (#4604). Runs on
// Linux and macOS.
import FlareModel
import Foundation
import SuiteModel
import Testing

struct FlareSuiteFixtureTests {
    /// A fresh folder holding Bounce.flare and Title.flare, as UITests/Fixtures/suite does.
    private func folders() throws -> (support: String, documents: String) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("flare-suite-fixture-\(UUID().uuidString)").path
        let documents = root + "/Fixtures"
        try FileManager.default.createDirectory(atPath: documents, withIntermediateDirectories: true)
        for file in ["Bounce.flare", "Title.flare"] {
            try Data(file.utf8).write(to: URL(fileURLWithPath: documents + "/" + file))
        }
        return (root + "/Support", documents)
    }

    @Test func suiteFixtureSeedsTheSharedRecentsAndDocuments() throws {
        let (support, documents) = try folders()
        let arguments = ["Flare", "-SuiteSupportDir", support, "-SuiteFixture", "weekOfWork",
                         "-SuiteFixtureDocuments", documents, "-FlareOpenFile", "/tmp/Logo.flare"]
        #expect(FlareLaunch.suiteFixture(in: arguments) == "weekOfWork")
        #expect(FlareLaunch.seedSuiteFixture(arguments: arguments, support: support))
        let recents = try FileStore(folder: support).read("recents.json", as: RecentsList.self).value
        let flare = (recents?.items ?? []).filter { $0.ref.app == .flare }.map(\.ref.displayName)
        #expect(flare.contains("Bounce.flare") && flare.contains("Title.flare"))
        #expect(FileManager.default.fileExists(atPath: support + "/Documents/Bounce.flare"))
        #expect(FileManager.default.fileExists(atPath: support + "/Documents/Title.flare"))
    }

    @Test func noSuiteFixtureLeavesTheStoreAlone() throws {
        let (support, documents) = try folders()
        let arguments = ["Flare", "-SuiteSupportDir", support, "-SuiteFixtureDocuments", documents]
        #expect(FlareLaunch.suiteFixture(in: arguments) == nil)
        #expect(!FlareLaunch.seedSuiteFixture(arguments: arguments, support: support))
        #expect(!FileManager.default.fileExists(atPath: support + "/recents.json"))
    }

    @Test func anUnknownSuiteFixtureSeedsNothing() throws {
        let (support, _) = try folders()
        #expect(!FlareLaunch.seedSuiteFixture(arguments: ["-SuiteFixture", "nope"], support: support))
        #expect(!FileManager.default.fileExists(atPath: support + "/recents.json"))
    }
}
