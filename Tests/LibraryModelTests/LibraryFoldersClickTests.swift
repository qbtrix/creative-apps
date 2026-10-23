// LibraryFoldersClickTests.swift (folders FO-6): a FOLDERS row's click and context menu on the catalog. A row's
// click shows its folder in the grid and selects that row; Include Subfolders turns the folder's subfolders'
// photos the other way and a later click on the row keeps that choice; a collection's click drops the folder
// rule and selects the collection. Fails when the grid doesn't follow the click (LJ-FO's step). Linux-safe.
import Testing
@testable import LibraryModel

@Suite struct LibraryFoldersClickTests {
    static let trips = LibraryFolders.rowID(for: "/p/trips")
    static let year = LibraryFolders.rowID(for: "/p/trips/2025")

    static func shown(_ c: LibraryCatalog) -> [String] { c.shownItems.map(\.name).sorted() }

    @Test func aRowsIdLeadsToItsFolder() {
        let c = LibraryFoldersTests.catalog(LibraryFoldersTests.trips)
        #expect(c.folderPath(forRow: Self.year) == "/p/trips/2025")
        #expect(c.folderPath(forRow: LibraryFolders.rowID(for: "/p/trip")) == "/p/trip")
        #expect(c.folderPath(forRow: LibraryFolders.rowID(for: "/p/nowhere")) == nil)
        #expect(c.folderPath(forRow: "all") == nil)
    }

    @Test func aClickShowsTheFolderAndSelectsItsRow() {
        var c = LibraryFoldersTests.catalog(LibraryFoldersTests.trips)
        #expect(c.sidebarSelection == c.selectedCollectionID)
        c.selectSidebarRow(Self.year)
        #expect(Self.shown(c) == ["lisbon.png", "porto.png"])
        #expect(c.sidebarSelection == Self.year)
        c.selectSidebarRow(Self.trips)
        #expect(Self.shown(c) == ["coast.png", "kyoto.png", "lisbon.png", "porto.png"], "a click shows subfolders")
        #expect(c.folderIncludesSubfolders(row: Self.trips))
    }

    @Test func includeSubfoldersFlipsAndAClickKeepsIt() {
        var c = LibraryFoldersTests.catalog(LibraryFoldersTests.trips)
        c.selectSidebarRow(Self.year)
        c.toggleFolderSubfolders(row: Self.trips)
        #expect(Self.shown(c) == ["coast.png"])
        #expect(!c.folderIncludesSubfolders(row: Self.trips))
        #expect(c.sidebarSelection == Self.trips)
        c.selectSidebarRow(Self.trips)
        #expect(Self.shown(c) == ["coast.png"], "a click on the shown folder forgot Include Subfolders")
        c.toggleFolderSubfolders(row: Self.trips)
        #expect(Self.shown(c) == ["coast.png", "kyoto.png", "lisbon.png", "porto.png"])
    }

    @Test func aCollectionsClickDropsTheFolderRule() {
        var c = LibraryFoldersTests.catalog(LibraryFoldersTests.trips)
        c.selectSidebarRow(Self.year)
        c.selectSidebarRow("all")
        #expect(c.activeFilter.folder == nil)
        #expect(c.sidebarSelection == "all")
        #expect(Self.shown(c).count == LibraryFoldersTests.trips.count)
    }

    @Test func anUnknownRowChangesNothing() {
        var c = LibraryFoldersTests.catalog(LibraryFoldersTests.trips)
        let before = c
        c.selectSidebarRow(LibraryFolders.rowID(for: "/p/nowhere"))
        c.toggleFolderSubfolders(row: LibraryFolders.rowID(for: "/p/nowhere"))
        #expect(c == before)
    }
}
