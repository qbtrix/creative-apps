// LibraryFoldersFixtureTests.swift: the folders quality gate's Model checks (#5843). The `large-folders`
// fixture gives the 10,000 photos real paths, so the FOLDERS render budget measures the tree built from them,
// not a hand-made sample; the `folders` fixture is the snapshot's tree (trips with 2025 and 2026, trip, and
// family, every file missing). view.show-folder takes a path with a trailing `/` as the same folder. Fails when
// a fixture's tree changes shape or a trailing slash is refused. Linux-safe.
@testable import SuiteKernel
import Testing
@testable import LibraryModel

@Suite struct LibraryFoldersFixtureTests {
    @Test func theLargeFoldersFixtureBuildsATreeFromItsTenThousandPhotos() throws {
        let photos = LibraryFixtures.photos(named: "large-folders")
        #expect(photos.count == 10_000)
        let roots = LibraryFolders.tree(photos)
        let root = try #require(roots.first)
        #expect(roots.count == 1)
        #expect(root.totalCount == 10_000)
        #expect(root.children.count == 12, "one folder per month")
        #expect(root.children.allSatisfy { $0.children.map(\.name) == ["selects"] }, "each month opens to selects")
    }

    @Test func theFoldersFixtureIsTheSnapshotsTree() {
        let roots = LibraryFolders.tree(LibraryFixtures.photos(named: "folders"))
        #expect(roots.map(\.name) == ["family", "trip", "trips"])
        #expect(roots.map(\.allMissing) == [true, false, false])
        #expect(roots.last?.children.map(\.name) == ["2025", "2026"])
        #expect(roots.map(\.totalCount) == [2, 1, 4])
    }

    @Test func showFolderTakesATrailingSlash() throws {
        let folders = try #require(LibraryFoldersTests.folders)
        var c = LibraryFoldersTests.catalog(LibraryFoldersTests.trips)
        _ = try folders.run("view.show-folder", params: .object(["path": .string("/p/trips/"), "subfolders": .bool(false)]), on: &c)
        #expect(c.shownItems.map(\.name) == ["coast.png"])
        #expect(c.activeFilter.folder == FolderScope(path: "/p/trips", subfolders: false), "the rule keeps the tree's path")
        _ = try folders.run("view.show-folder", params: .object(["path": .string("/p/trips/2025//")]), on: &c)
        #expect(c.shownItems.map(\.name).sorted() == ["lisbon.png", "porto.png"])
    }
}
