// LibraryInspectorSnapshots.swift: Library's inspector with its one header
// above the Info and Develop tabs (status-and-layout SL-6), on the shoot
// fixture sorted by name, Light and Dark, at UTC: IMG_0001 alone
// (`library-inspector`: Captured, Size and Kind) and IMG_0001 … IMG_0005
// (`library-inspector-several`: "5 Photos", the active IMG_0001 and the
// capture day). With nothing selected the header names the collection and its count
// (`library-inspector-none` is LibraryShellSnapshots'). The header carries
// `library.inspector.header`, and MetadataInspector draws no title of its own
// (#2982), so the inspector shows one. macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

@MainActor
@Suite struct LibraryInspectorSnapshots {
    /// The shoot sorted by name, on live data, with its first `count` photos selected.
    private func shoot(selecting count: Int) throws -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        catalog.services.isPreview = false
        catalog.setSort(.name)
        try #require(catalog.order.count == 24)
        catalog.select(Set(catalog.sortedItems.prefix(count).map(\.id)))
        return catalog
    }

    @Test func onePhoto() throws {
        let catalog = try shoot(selecting: 1)
        let header = catalog.inspectorHeader(utcOffset: 0)
        #expect(header.title == "IMG_0001")
        #expect(header.facts.map(\.label) == ["Captured", "Size", "Kind"])
        #expect(header.facts.map(\.value) == ["2026-06-01 10:07", "6000 × 4000", "JPEG"])
        try shoot(catalog, "library-inspector")
    }

    @Test func severalPhotos() throws {
        let catalog = try shoot(selecting: 5)
        let header = catalog.inspectorHeader(utcOffset: 0)
        #expect(header.title == "5 Photos")
        #expect(header.facts.map(\.label) == ["Active", "Captured"])
        #expect(header.facts.map(\.value) == ["IMG_0001", "2026-06-01"])
        try shoot(catalog, "library-inspector-several")
    }

    /// Nothing selected: the collection's name and "Photos 24", still one header.
    @Test func nothingSelected() throws {
        let catalog = try shoot(selecting: 0)
        let header = catalog.inspectorHeader(utcOffset: 0)
        #expect(!header.title.isEmpty && header.title == catalog.selectedCollection?.name)
        #expect(header.facts.map(\.value) == ["24"])
    }

    @Test func headerIdentifier() {
        #expect(LibraryInspector.headerID == "library.inspector.header")
    }

    /// #291: the tab switch and each of its segments carry a library.* identifier (scoped run 39207561728
    /// found the Info and Develop radio buttons without one), and J11's id order clicks develop before info.
    @Test func tabIdentifiers() {
        #expect(LibraryInspector.tabsID == "library.inspector.tabs")
        #expect(LibraryInspector.tabs.map(\.id) == [.info, .develop])
        #expect(LibraryInspector.tabs.map(\.title) == ["Info", "Develop"])
        let ids = LibraryInspector.tabs.compactMap(\.identifier)
        #expect(ids == ["library.inspector.info", "library.inspector.develop"])
        #expect(Set(ids + [LibraryInspector.tabsID]).count == 3)
        #expect(ids.sorted() == ["library.inspector.develop", "library.inspector.info"])
        #expect(ids.allSatisfy { $0 < LibraryInspector.tabsID })
    }

    /// The inspector at its ideal width on the panel, as LibraryShellSnapshots draws it.
    private func shoot(_ catalog: LibraryCatalog, _ name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                LibraryInspector(model: catalog, utcOffset: 0)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 900, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
