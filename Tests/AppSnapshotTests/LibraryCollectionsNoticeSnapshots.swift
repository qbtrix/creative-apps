// LibraryCollectionsNoticeSnapshots.swift: the damaged collections file
// (filters-collections FC-13; slice FC-e). The sample photos after a
// collections file that couldn't be read was set aside: no collections of
// yours, All Photos selected, the warning notice in the browser's notice
// slot. Written before its code: FC-14 builds `failRestoreCollections` and
// drops the `.disabled` trait. Writes library-collections-damaged-{light,dark}.png.
// macOS only.
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryCollectionsNoticeSnapshots {
    @Test(.disabled("waits on FC-14")) func damaged() throws {
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
