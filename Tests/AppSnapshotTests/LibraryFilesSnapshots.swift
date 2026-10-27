// LibraryFilesSnapshots.swift (catalog-files LC-3): the import copy choice and the missing badge, disabled on
// the LC-1 stubs, in Light and Dark. The remove confirm is a system dialog, so its words are checked. macOS only.
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

@MainActor
@Suite struct LibraryFilesSnapshots {
    /// Twelve sample photos with their thumbnails, the 2nd, 6th and 10th missing their files.
    static func missingThree() -> LibraryCatalog {
        var samples = LibraryCatalog()
        samples.loadSamples()
        let photos = samples.sortedItems.prefix(12).enumerated().map { index, photo in
            var photo = photo
            if index % 4 == 1 { photo.availability = .missing }
            return photo
        }
        var library = LibraryCatalog()
        library.load(Array(photos))
        return library.answeringThumbnails()
    }

    @Test func filesControls() throws {
        let library = Self.missingThree()
        #expect(library.missingCount == 3)
        #expect(LibraryCatalog.missingBadgeTitle(count: library.missingCount) == "3 photos are missing")
        let files = LibraryFilesActions()
        #expect(files.remove == nil && files.locate == nil)
        #expect(files.removeWhy == "File management arrives with LC-5." && files.locateWhy == files.removeWhy)
        for scheme in [ColorScheme.light, .dark] {
            let name = scheme == .dark ? "dark" : "light"
            try snapshot(
                LibraryImportOptions().frame(width: 1440, height: 900),
                name: "library-import-copy-options-\(name)", scheme: scheme)
            try snapshot(
                LibraryBrowser(model: library).frame(width: 1440, height: 900, alignment: .top),
                name: "library-missing-locate-\(name)", scheme: scheme)
        }
    }

    @Test func removeConfirmWords() {
        var library = Self.missingThree()
        library.select(Set(library.order.prefix(3)))
        #expect(LibraryCatalog.removeConfirmTitle(count: library.removeCount) == "Remove 3 Photos from the Catalog?")
        #expect(LibraryCatalog.fileCommands.availability("photo.remove-from-catalog", on: library).why
            == LibraryCatalog.catalogFilesHelp)
    }
}
