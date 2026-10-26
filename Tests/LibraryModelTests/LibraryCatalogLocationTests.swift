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

    @Test func libraryFolder() {
        #expect(LibrarySupport.catalogFolder(arguments: [], home: Self.home)
            == "/Users/ana/Library/Application Support/AfterGlow/Library")
        #expect(LibrarySupport.catalogFolder(arguments: ["LibraryApp", "-SuiteSupportDir", "/t"], home: Self.home)
            == "/t/Library")
        #expect(LibrarySupport.catalogFolder(arguments: [], home: Self.home)
            == SuiteLocations.appFolder("Library", arguments: [], home: Self.home))
    }

    @Test func catalogDirWins() {
        #expect(LibrarySupport.catalogFolder(arguments: ["-LibraryCatalogDir", "/c"], home: Self.home) == "/c")
        #expect(LibrarySupport.catalogFolder(
            arguments: ["-SuiteSupportDir", "/t", "-LibraryCatalogDir", "/c"], home: Self.home) == "/c")
        #expect(LibrarySupport.catalogFolder(
            arguments: ["-LibraryCatalogDir", "/c", "-SuiteSupportDir", "/t"], home: Self.home) == "/c")
    }

    @Test func oldCatalogIsUnderApplicationSupport() {
        #expect(Self.oldCatalog == "/Users/ana/Library/Application Support/Library/catalog.json")
        #expect(Self.oldCatalog != Self.newCatalog([]))
    }

    @Test func oldCatalogMovesOnce() {
        let arguments = ["-SuiteSupportDir", "/t"]
        var files: Set<String> = [Self.oldCatalog]
        #expect(Self.migrate(&files, arguments: arguments) == .move(from: Self.oldCatalog, to: "/t/Library/catalog.json"))
        #expect(files == ["/t/Library/catalog.json"])
        #expect(Self.migrate(&files, arguments: arguments) == .nothing)
        #expect(files == ["/t/Library/catalog.json"])
    }

    @Test func oldAndNewAreBothKept() {
        let arguments = ["-SuiteSupportDir", "/t"]
        var files: Set<String> = [Self.oldCatalog, "/t/Library/catalog.json"]
        #expect(Self.migrate(&files, arguments: arguments) == .keepBoth(old: Self.oldCatalog))
        #expect(files == [Self.oldCatalog, "/t/Library/catalog.json"])
        #expect(Self.migrate(&files, arguments: arguments) == .keepBoth(old: Self.oldCatalog))
    }

    @Test func noOldCatalogDoesNothing() {
        var files: Set<String> = []
        #expect(Self.migrate(&files, arguments: []) == .nothing)
        #expect(files.isEmpty)
        var onlyNew: Set<String> = [Self.newCatalog([])]
        #expect(Self.migrate(&onlyNew, arguments: []) == .nothing)
        #expect(onlyNew == [Self.newCatalog([])])
    }

    /// The store's step: on the real root the old catalog moves once, and never over a newer one.
    @Test func storeStepOnTheRealRoot() {
        let new = Self.newCatalog([])
        #expect(LibrarySupport.legacyCatalogStep(arguments: ["LibraryApp"], home: Self.home,
            exists: { $0 == Self.oldCatalog }) == .move(from: Self.oldCatalog, to: new))
        #expect(LibrarySupport.legacyCatalogStep(arguments: [], home: Self.home,
            exists: { $0 == Self.oldCatalog || $0 == new }) == .keepBoth(old: Self.oldCatalog))
        #expect(LibrarySupport.legacyCatalogStep(arguments: [], home: Self.home, exists: { _ in false }) == .nothing)
    }

    /// A launch on another folder (journeys, tests) never moves the person's real old catalog.
    @Test func storeStepLeavesRealFilesUnderAnOverride() {
        for arguments in [["-SuiteSupportDir", "/t"], ["-LibraryCatalogDir", "/c"]] {
            #expect(LibrarySupport.legacyCatalogStep(arguments: arguments, home: Self.home,
                exists: { $0 == Self.oldCatalog }) == .nothing)
        }
    }

    /// The store's folder: a named one, then the registered default, then the launch's.
    @Test func storeFolderOrder() {
        let launch = LibrarySupport.catalogFolder(arguments: [], home: Self.home)
        #expect(LibrarySupport.storeFolder(named: "/n", registered: "/r", arguments: [], home: Self.home) == "/n")
        #expect(LibrarySupport.storeFolder(named: nil, registered: "/r", arguments: [], home: Self.home) == "/r")
        #expect(LibrarySupport.storeFolder(named: nil, registered: "", arguments: [], home: Self.home) == launch)
        #expect(LibrarySupport.storeFolder(named: nil, registered: nil, arguments: [], home: Self.home) == launch)
    }

    /// A named folder or a registered default (a test process) never moves the real old catalog.
    @Test func storeMovesLegacyOnlyOnTheLaunchFolder() {
        #expect(LibrarySupport.storeMovesLegacy(named: nil, registered: nil))
        #expect(LibrarySupport.storeMovesLegacy(named: nil, registered: ""))
        #expect(!LibrarySupport.storeMovesLegacy(named: "/n", registered: nil))
        #expect(!LibrarySupport.storeMovesLegacy(named: nil, registered: "/r"))
    }
}
