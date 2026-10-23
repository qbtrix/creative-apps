// LibraryCatalogLocationTests.swift (adopt-kernel-autosave MJ-AK-library, AK-5
// written, AK-6 on): Library's catalog lives in `<support>/Library`,
// `-SuiteSupportDir` reaches it, `-LibraryCatalogDir` wins over both, and a
// catalog at the earlier place moves there once and never over a newer one.
// The moves run on an in-memory set of paths, so the rule is checked on Linux.
import LibraryModel
import SuiteModel
import Testing

@Suite struct LibraryCatalogLocationTests {
    static let home = "/Users/ana"
    static let catalogName = "catalog.json"

    /// The earlier build's catalog under `home`.
    static var oldCatalog: String { SuiteLocations.legacyFolder(LibrarySupport.legacyCatalog, home: home) }

    /// The catalog file in the folder the arguments pick.
    static func newCatalog(_ arguments: [String]) -> String {
        LibrarySupport.catalogFolder(arguments: arguments, home: home) + "/" + catalogName
    }

    /// Runs the move-once rule against `files`, applying a move; returns the step.
    static func migrate(_ files: inout Set<String>, arguments: [String]) -> LegacySupport.Step {
        let present = files
        let step = LegacySupport.plan(old: oldCatalog, new: newCatalog(arguments), exists: { present.contains($0) })
        if case let .move(from, to) = step {
            files.remove(from)
            files.insert(to)
        }
        return step
    }

    @Test(.disabled("waits on AK-6")) func libraryFolder() {
        #expect(LibrarySupport.catalogFolder(arguments: [], home: Self.home)
            == "/Users/ana/Library/Application Support/AfterGlow/Library")
        #expect(LibrarySupport.catalogFolder(arguments: ["LibraryApp", "-SuiteSupportDir", "/t"], home: Self.home)
            == "/t/Library")
        #expect(LibrarySupport.catalogFolder(arguments: [], home: Self.home)
            == SuiteLocations.appFolder("Library", arguments: [], home: Self.home))
    }

    @Test(.disabled("waits on AK-6")) func catalogDirWins() {
        #expect(LibrarySupport.catalogFolder(arguments: ["-LibraryCatalogDir", "/c"], home: Self.home) == "/c")
        #expect(LibrarySupport.catalogFolder(
            arguments: ["-SuiteSupportDir", "/t", "-LibraryCatalogDir", "/c"], home: Self.home) == "/c")
        #expect(LibrarySupport.catalogFolder(
            arguments: ["-LibraryCatalogDir", "/c", "-SuiteSupportDir", "/t"], home: Self.home) == "/c")
    }

    @Test(.disabled("waits on AK-6")) func oldCatalogIsUnderApplicationSupport() {
        #expect(Self.oldCatalog == "/Users/ana/Library/Application Support/Library/catalog.json")
        #expect(Self.oldCatalog != Self.newCatalog([]))
    }

    @Test(.disabled("waits on AK-6")) func oldCatalogMovesOnce() {
        let arguments = ["-SuiteSupportDir", "/t"]
        var files: Set<String> = [Self.oldCatalog]
        #expect(Self.migrate(&files, arguments: arguments) == .move(from: Self.oldCatalog, to: "/t/Library/catalog.json"))
        #expect(files == ["/t/Library/catalog.json"])
        #expect(Self.migrate(&files, arguments: arguments) == .nothing)
        #expect(files == ["/t/Library/catalog.json"])
    }

    @Test(.disabled("waits on AK-6")) func oldAndNewAreBothKept() {
        let arguments = ["-SuiteSupportDir", "/t"]
        var files: Set<String> = [Self.oldCatalog, "/t/Library/catalog.json"]
        #expect(Self.migrate(&files, arguments: arguments) == .keepBoth(old: Self.oldCatalog))
        #expect(files == [Self.oldCatalog, "/t/Library/catalog.json"])
        #expect(Self.migrate(&files, arguments: arguments) == .keepBoth(old: Self.oldCatalog))
    }

    @Test(.disabled("waits on AK-6")) func noOldCatalogDoesNothing() {
        var files: Set<String> = []
        #expect(Self.migrate(&files, arguments: []) == .nothing)
        #expect(files.isEmpty)
        var onlyNew: Set<String> = [Self.newCatalog([])]
        #expect(Self.migrate(&onlyNew, arguments: []) == .nothing)
        #expect(onlyNew == [Self.newCatalog([])])
    }
}
