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
        // Three photos by display position, all within the first two rows, so
        // every selection ring is in the capture.
        let order = loaded.sortedItems.map(\.id)
        let picks = Set([1, 4, 10].compactMap { order.indices.contains($0) ? order[$0] : nil })
        #expect(picks.count == 3)
        var selected = loaded
        selected.select(picks)
        #expect(selected.selection == picks)
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(topAligned(LibraryBrowser(model: loaded)), name: "library-grid-\(suffix)", scheme: scheme)
            try snapshot(
                topAligned(LibraryBrowser(model: selected)), name: "library-grid-selected-\(suffix)", scheme: scheme)
        }
    }

    /// ImageRenderer drops the grid's ScrollView, so the full grid is taller
    /// than the frame. Pin it to the top, where the real ScrollView starts.
    private func topAligned(_ view: some View) -> some View {
        view.frame(width: 1440, height: 900, alignment: .top)
    }
}
