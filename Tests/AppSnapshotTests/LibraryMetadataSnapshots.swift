// LibraryMetadataSnapshots.swift: Library's MetadataInspector for one rated,
// blue-labelled sample photo, and for three photos with mixed ratings, in
// Light and Dark. Writes library-metadata-{light,dark}.png and
// library-metadata-mixed-{light,dark}.png. macOS only.
import LibraryModel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryMetadataSnapshots {
    @Test func metadataInspector() throws {
        var one = LibraryCatalog()
        one.loadSamples()
        let order = one.sortedItems.map(\.id)
        var mixed = one
        one.select(Set(order.prefix(1)))
        one.setRating(4)
        one.setLabel(.blue)
        mixed.select(Set(order.prefix(3)))
        mixed.setRating(2)
        mixed.select(Set(order.prefix(1)))
        mixed.setRating(5)
        mixed.select(Set(order.prefix(3)))
        let single = try #require(one.selectedMetadata)
        let several = try #require(mixed.selectedMetadata)
        #expect(single.rating == .value(4) && single.label == .value(.blue))
        #expect(several.rating == .mixed && several.title == "3 Photos")
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(panel(single), name: "library-metadata-\(suffix)", scheme: scheme)
            try snapshot(panel(several), name: "library-metadata-mixed-\(suffix)", scheme: scheme)
        }
    }

    private func panel(_ metadata: PhotoMetadata) -> some View {
        MetadataInspector(metadata: metadata)
            .frame(width: SuiteSize.inspectorWidth.ideal, height: 900, alignment: .topLeading)
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
    }
}
