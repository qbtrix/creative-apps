// LibraryFoldersSidebarTests.swift (folders FO-3): what the sidebar's FOLDERS section reads from the catalog.
// A row's id is `library.folder.` and the FNV-1a hash of its path as 16 hex digits, so it is the same in every
// process and never collides with a collection's id; `folderTree` is `LibraryFolders.tree` of the photos;
// `showFolderHelp` is view.show-folder's reason. Fails when an id drifts between paths that share a prefix, when
// a collection id reads as a folder row, or when the help disagrees with the command's availability. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
@testable import LibraryModel

@Suite struct LibraryFoldersSidebarTests {
    @Test func aRowIdIsThePathsStableHash() {
        #expect(LibraryFolders.rowID(for: "/p/trips") == "library.folder.cbaee634ffa36c29")
        #expect(LibraryFolders.rowID(for: "") == "library.folder.cbf29ce484222325")
        #expect(LibraryFolders.rowID(for: "/p/trips") != LibraryFolders.rowID(for: "/p/trip"))
        #expect(LibraryFolders.rowID(for: "/p/trips") != LibraryFolders.rowID(for: "/p/trips/2025"))
    }

    @Test func onlyAFolderRowsIdReadsAsOne() {
        #expect(LibraryFolders.isRowID(LibraryFolders.rowID(for: "/p/family")))
        for id in ["all", "favorites", "recent", "smart-1", "library.folder", "library.folders./p", "library.folder./p/trips"] {
            #expect(!LibraryFolders.isRowID(id), "\(id) read as a folder row")
        }
    }

    @Test func theTreeAndTheHelpComeFromTheCatalog() {
        let empty = LibraryFoldersTests.catalog([])
        #expect(empty.folderTree.isEmpty)
        #expect(empty.showFolderHelp == "Import a folder to see its folders.")
        let trips = LibraryFoldersTests.catalog(LibraryFoldersTests.trips)
        #expect(trips.folderTree == LibraryFolders.tree(trips.items))
        // The stub: with photos, view.show-folder isn't built yet (FO-5 makes this nil).
        #expect(trips.showFolderHelp == "Folders arrive with FO-4.")
    }
}
