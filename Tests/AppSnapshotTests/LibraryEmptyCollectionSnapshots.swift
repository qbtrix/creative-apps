// LibraryEmptyCollectionSnapshots.swift: Library's browser on Favorites when the
// catalog has photos but none is flagged: the empty state, not a blank grid.
// Writes library-empty-collection-{light,dark}.png. macOS only.
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryEmptyCollectionSnapshots {
    @Test func emptyCollection() throws {
        var catalog = LibraryCatalog()
        catalog.load(LibrarySample.items().filter { !$0.isFlagged })
        catalog.selectCollection("favorites")
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(LibraryBrowser(model: catalog), name: "library-empty-collection-\(suffix)", scheme: scheme)
        }
    }
}
