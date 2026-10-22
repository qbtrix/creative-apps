// LibraryShareSnapshots.swift: Library's grid with three sample photos selected
// and the Share button (share-sheet SH-4) in its top-trailing corner, off with
// the stubs' reason, in Light and Dark. Writes
// library-grid-share-button-{light,dark}.png. macOS only.
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryShareSnapshots {
    @Test func gridShareButton() throws {
        var samples = LibraryCatalog()
        samples.loadSamples()
        var selected = samples.answeringThumbnails()
        selected.select(Set(selected.sortedItems.prefix(3).map(\.id)))
        #expect(selected.selection.count == 3)
        #expect(selected.shareHelp == SharePrep.notBuilt)
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(
                LibraryBrowser(model: selected).frame(width: 1440, height: 900, alignment: .top),
                name: "library-grid-share-button-\(suffix)", scheme: scheme)
        }
    }
}
