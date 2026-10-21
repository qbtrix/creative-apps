// LibraryCollectionsNoticeSnapshots.swift: the samples after a damaged
// collections file was set aside (filters-collections FC-13; slice FC-e).
// Enabled by FC-14. library-collections-damaged-{light,dark}.png.
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryCollectionsNoticeSnapshots {
    @Test func damaged() throws {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        catalog.failRestoreCollections(setAsideAs: "collections.json.bad")
        #expect(catalog.collectionsNotice
            == "Library couldn't read your collections. The file was set aside as collections.json.bad.")
        #expect(catalog.userCollections.isEmpty)
        #expect(catalog.selectedCollectionID == "all")
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(
                LibraryBrowser(model: catalog).frame(width: 1440, height: 900, alignment: .top),
                name: "library-collections-damaged-\(suffix)", scheme: scheme)
        }
    }
}
