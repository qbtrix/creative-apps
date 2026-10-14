// LibraryLoupeSnapshots.swift: Library's browser in loupe mode on the 12th
// sample photo, fitted in CanvasSurface with its "12 of 60" readout, in Light
// and Dark. Writes library-loupe-{light,dark}.png. macOS only.
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryLoupeSnapshots {
    @Test func loupe() throws {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        let order = catalog.sortedItems.map(\.id)
        try #require(order.count == 60)
        catalog.open(order[11])
        #expect(catalog.loupePosition == "12 of 60")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                LibraryBrowser(model: catalog),
                name: "library-loupe-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
