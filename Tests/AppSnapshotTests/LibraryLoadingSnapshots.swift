// LibraryLoadingSnapshots.swift: Library's browser while the launch read
// runs (persist, PE-8): blank content, no "No Photos" flash.
// Writes library-loading-{light,dark}.png. macOS only.
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryLoadingSnapshots {
    @Test func loading() throws {
        var catalog = LibraryCatalog()
        catalog.beginRestore()
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(LibraryBrowser(model: catalog), name: "library-loading-\(suffix)", scheme: scheme)
        }
    }
}
