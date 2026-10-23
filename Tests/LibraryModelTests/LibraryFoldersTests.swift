// LibraryFoldersTests.swift (folders FO-1, written before the bodies): the FOLDERS tree and its two commands.
// The stub checks run now: the specs' ids, kinds, schemas and reasons, and their runs refuse as not built.
// FO-4 turned on the tree checks (three imports give three roots, a chain collapses into one row, own and total
// counts, `/a/bc` never under `/a/b`, all-missing folders, 10,000 paths under a 20 ms median); FO-5 the filter checks
// (subfolders off shows only a folder's own photos, on its descendants' too, `folders.list` matches the tree).
// Fails when a count is off, a sibling counts as a child, or the filter leaks another folder's photos. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import SuiteKernel
import Testing
@testable import LibraryModel

@Suite struct LibraryFoldersTests {
    /// A photo at `path`, named after its file, missing from disk when `missing`.
    static func photo(_ path: String, missing: Bool = false) -> PhotoItem {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return PhotoItem(id: path, name: name, captureDate: .distantPast, color: Color3(0.5, 0.5, 0.5), path: path,
                         availability: missing ? .missing : .available)
    }

    /// The trips fixture: trips/ with 2025/ and 2026/ inside, trip/ (a name prefix of trips) and family/.
    static let trips = [
        "/p/trips/coast.png", "/p/trips/2025/lisbon.png", "/p/trips/2025/porto.png", "/p/trips/2026/kyoto.png",
        "/p/trip/tripod.png", "/p/family/birthday.png",
    ].map { photo($0) }

    /// The node at `path` anywhere in `nodes`.
    static func node(_ path: String, in nodes: [FolderNode]) -> FolderNode? {
        for n in nodes {
            if n.path == path { return n }
            if let hit = node(path, in: n.children) { return hit }
        }
        return nil
    }

    /// The catalog holding `photos`, with fakes behind it.
    static func catalog(_ photos: [PhotoItem]) -> LibraryCatalog {
        var c = LibraryCatalog(services: .fake())
        c.load(photos)
        return c
    }

    static let folders = try? CommandCatalog(app: "library", LibraryCatalog.folderSpecs,
                                             history: { LibraryCatalogSteps(catalog: $0) })

    // MARK: The specs (FO-1, FO-5)

    @Test func theSpecsHaveTheirIdsKindsAndSchemas() throws {
        let folders = try #require(Self.folders)
        #expect(folders.ids == ["folders.list", "view.show-folder"])
        #expect(folders.spec("folders.list")?.kind == .query)
        #expect(folders.spec("view.show-folder")?.kind == .view)
        let show = try #require(folders.spec("view.show-folder"))
        #expect(show.params.validate(show.example).isEmpty)
        #expect(show.params.validate(.object(["path": .string("/p/trips")])).isEmpty)
        #expect(!show.params.validate(.object(["subfolders": .bool(true)])).isEmpty, "path is required")
        #expect(!show.params.validate(.object(["path": .string("/p"), "depth": .number(1)])).isEmpty, "closed object")
        let ids = Set(LibraryCatalog.commands.map(\.id))
        #expect(ids.isSuperset(of: ["folders.list", "view.show-folder"]), "the catalog appends the folder specs")
    }

    @Test func theCommandsSayWhyWithoutFolders() throws {
        let folders = try #require(Self.folders)
        let empty = Self.catalog([]), samples = Self.catalog(LibrarySample.items(seed: LibrarySample.defaultSeed))
        for id in ["folders.list", "view.show-folder"] {
            #expect(folders.availability(id, on: empty).why == LibraryCatalog.noFolders, "\(id) on no photos")
            #expect(folders.availability(id, on: samples).why == LibraryCatalog.noFolders, "\(id) on photos in no folder")
            #expect(folders.availability(id, on: Self.catalog(Self.trips)).why == nil, "\(id) on the trips")
        }
    }

    // MARK: The tree (FO-4)

    @Test func threeImportsGiveThreeRoots() {
        let photos = ["/Volumes/Card/DCIM/a.jpg", "/Users/me/family/b.jpg", "/Users/me/family/kids/c.jpg",
                      "/srv/pets/d.jpg"].map { Self.photo($0) }
        let roots = LibraryFolders.tree(photos)
        #expect(roots.map(\.path).sorted() == ["/Users/me/family", "/Volumes/Card/DCIM", "/srv/pets"])
        #expect(roots.map(\.totalCount).reduce(0, +) == 4)
    }

    @Test func aChainWithPhotosOnlyAtTheEndIsOneRow() {
        let roots = LibraryFolders.tree([Self.photo("/a/b/c/one.png"), Self.photo("/a/b/c/two.png")])
        #expect(roots.count == 1)
        #expect(roots.first?.name == "a/b/c")
        #expect(roots.first?.path == "/a/b/c")
        #expect(roots.first?.children.isEmpty == true)
        #expect(roots.first?.ownCount == 2)
    }

    @Test func countsWithAndWithoutDescendants() throws {
        let roots = LibraryFolders.tree(Self.trips)
        let trips = try #require(Self.node("/p/trips", in: roots))
        #expect(trips.ownCount == 1)
        #expect(trips.totalCount == 4)
        #expect(trips.children.map(\.name) == ["2025", "2026"])
        #expect(Self.node("/p/trips/2025", in: roots)?.ownCount == 2)
        #expect(Self.node("/p/trips/2025", in: roots)?.totalCount == 2)
        #expect(Self.node("/p/trips/2026", in: roots)?.totalCount == 1)
    }

    @Test func aSiblingWhoseNameIsAPrefixIsNotAChild() throws {
        let roots = LibraryFolders.tree(["/a/b/x.png", "/a/bc/y.png"].map { Self.photo($0) })
        #expect(Self.node("/a/b", in: roots)?.children.isEmpty == true)
        #expect(Self.node("/a/b", in: roots)?.totalCount == 1)
        #expect(Self.node("/a/bc", in: roots)?.totalCount == 1)
        let trip = try #require(Self.node("/p/trip", in: LibraryFolders.tree(Self.trips)))
        #expect(trip.totalCount == 1, "trip/ never counts trips/' photos")
    }

    @Test func aFolderIsAllMissingOnlyWhenEveryPhotoUnderItIs() {
        let photos = [Self.photo("/m/gone/a.png", missing: true), Self.photo("/m/gone/sub/b.png", missing: true),
                      Self.photo("/m/half/c.png", missing: true), Self.photo("/m/half/d.png")]
        let roots = LibraryFolders.tree(photos)
        #expect(Self.node("/m/gone", in: roots)?.allMissing == true)
        #expect(Self.node("/m/half", in: roots)?.allMissing == false)
    }

    @Test func tenThousandPaths() {
        let photos = (0..<10_000).map { Self.photo("/big/\($0 % 20)/\($0 % 7)/\($0).png") }
        var roots: [FolderNode] = []
        let cost = Budget.measure("folders tree-of-10000-paths", runs: 10) { roots = LibraryFolders.tree(photos) }
        #expect(roots.map(\.totalCount).reduce(0, +) == 10_000)
        #expect(cost.median < 20, "tree of 10,000 paths took a median \(cost.median) ms")
    }

    // MARK: The filter and the commands (FO-5)

    /// The names of the photos the grid shows after `view.show-folder` on `path`.
    static func shown(_ path: String, subfolders: Bool?) throws -> [String] {
        let folders = try #require(Self.folders)
        var c = catalog(trips)
        var params: [String: JSONValue] = ["path": .string(path)]
        if let subfolders { params["subfolders"] = .bool(subfolders) }
        let outcome = try folders.run("view.show-folder", params: .object(params), on: &c)
        #expect(outcome.undoStep == nil, "showing a folder is view state, not an undo step")
        return c.shownItems.map(\.name).sorted()
    }

    @Test func filter() throws {
        #expect(try Self.shown("/p/trips", subfolders: false) == ["coast.png"])
        #expect(try Self.shown("/p/trips", subfolders: true) == ["coast.png", "kyoto.png", "lisbon.png", "porto.png"])
        #expect(try Self.shown("/p/trips", subfolders: nil) == ["coast.png", "kyoto.png", "lisbon.png", "porto.png"])
        #expect(try Self.shown("/p/trips/2025", subfolders: true) == ["lisbon.png", "porto.png"])
        #expect(try Self.shown("/p/trip", subfolders: true) == ["tripod.png"], "trip/ never shows trips/")
    }

    @Test func showFolderRefusesAnUnknownPath() throws {
        let folders = try #require(Self.folders)
        var c = Self.catalog(Self.trips)
        let before = c
        #expect(throws: CatalogError.unavailable(id: "view.show-folder", why: "There is no folder /p/nowhere.")) {
            try folders.run("view.show-folder", params: .object(["path": .string("/p/nowhere")]), on: &c)
        }
        #expect(c == before)
        #expect(throws: CatalogError.self) {
            try folders.run("view.show-folder", params: .object(["path": .string("/p/trip/tripod.png")]), on: &c)
        }
    }

    @Test func aSiblingWithASharedPrefixNeverLeaks() {
        let photos = ["/a/b/x.png", "/a/b/deep/z.png", "/a/bc/y.png"].map { Self.photo($0) }
        let names = { (scope: FolderScope) in photos.filter(LibraryFilter(folder: scope).matches).map(\.name) }
        #expect(names(FolderScope(path: "/a/b", subfolders: true)) == ["x.png", "z.png"])
        #expect(names(FolderScope(path: "/a/b", subfolders: false)) == ["x.png"])
        #expect(names(FolderScope(path: "/a/bc", subfolders: true)) == ["y.png"])
        #expect(names(FolderScope(path: "/a/b/deep", subfolders: false)) == ["z.png"])
        let loose = PhotoItem(name: "loose.png", captureDate: .distantPast, color: Color3(0.5, 0.5, 0.5))
        #expect(!LibraryFilter(folder: FolderScope(path: "/a", subfolders: true)).matches(loose), "a photo in no folder is in none")
    }

    @Test func theSummaryNamesTheFolder() {
        #expect(LibraryFilter(folder: FolderScope(path: "/p/trips", subfolders: true)).summary == "In trips and its subfolders")
        #expect(LibraryFilter(folder: FolderScope(path: "/p/trips", subfolders: false)).summary == "In trips")
        #expect(LibraryFilter(rating: .atLeast(3), folder: FolderScope(path: "/p/trips", subfolders: false)).summary
                == "At least 3 stars, In trips")
    }

    /// `nodes` as folders.list rows: pre-order, each with its depth.
    static func rows(_ nodes: [FolderNode], depth: Int = 0) -> [JSONValue] {
        nodes.flatMap { n -> [JSONValue] in
            let row: JSONValue = .object([
                "path": .string(n.path), "name": .string(n.name), "depth": .number(Double(depth)),
                "ownCount": .number(Double(n.ownCount)), "totalCount": .number(Double(n.totalCount)),
                "allMissing": .bool(n.allMissing),
            ])
            return [row] + rows(n.children, depth: depth + 1)
        }
    }

    @Test func listMatchesTheTree() throws {
        let folders = try #require(Self.folders)
        var c = Self.catalog(Self.trips)
        let result = try folders.run("folders.list", params: .object([:]), on: &c).result
        #expect(result == .object(["folders": .array(Self.rows(LibraryFolders.tree(Self.trips)))]))
        #expect(folders.spec("folders.list")?.result.validate(result).isEmpty == true)
    }
}
