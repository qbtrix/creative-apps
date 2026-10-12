// LibraryGridSnapshots.swift: Library's browser with the sample photos loaded,
// with nothing selected and with three photos selected, in Light and Dark.
// Writes library-grid-{light,dark}.png and library-grid-selected-{light,dark}.png.
// macOS only.
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryGridSnapshots {
    @Test func grid() throws {
        var loaded = LibraryCatalog()
        loaded.loadSamples()
        var selected = loaded
        selected.select(["IMG_0003", "IMG_0010", "IMG_0021"])
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(LibraryBrowser(model: loaded), name: "library-grid-\(suffix)", scheme: scheme)
            try snapshot(LibraryBrowser(model: selected), name: "library-grid-selected-\(suffix)", scheme: scheme)
        }
    }
}
