// LibraryGridSnapshots.swift: Library's browser with the sample photos loaded,
// with nothing selected and with three photos selected, in Light and Dark.
// Writes library-grid-{light,dark}.png and library-grid-selected-{light,dark}.png.
// The grid is pinned to the top, where its ScrollView starts, and the selection
// is taken from the first two rows in display order so every selected photo is
// in the 1440x900 capture. macOS only.
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryGridSnapshots {
    @Test func grid() throws {
        var loaded = LibraryCatalog()
        loaded.loadSamples()
        let order = loaded.sortedItems.map(\.id)
        let picks = [0, 3, 9].filter(order.indices.contains).map { order[$0] }
        #expect(picks.count == 3, "the samples fill at least two rows")
        var selected = loaded
        selected.select(Set(picks))
        #expect(selected.selection.count == 3)
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(LibraryBrowser(model: loaded), name: "library-grid-\(suffix)", scheme: scheme, alignment: .top)
            try snapshot(
                LibraryBrowser(model: selected), name: "library-grid-selected-\(suffix)", scheme: scheme, alignment: .top)
        }
    }
}
