// LibraryRatingSnapshots.swift: the cull feature's result (cull CU-5): the
// loupe on a sample photo culled to 3 stars, picked and red, with nothing
// selected in the grid: its glass readout ends with that cull state and the
// window's own LibraryInspector shows the loupe photo (#1661), beside the
// MetadataInspector for a second, rejected photo. Built only through the
// catalog's public cull methods, in Light and Dark. Writes library-rated-{light,dark}.png.
// macOS only.
import LibraryModel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryRatingSnapshots {
    @Test func ratedAndRejected() throws {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        let order = catalog.sortedItems.map(\.id)
        try #require(order.count >= 2)
        catalog.select([order[0]])
        catalog.cull(.rating(3))
        catalog.cull(.flag(.pick))
        catalog.cull(.label(.red))
        catalog.select([order[1]])
        catalog.cull(.flag(.reject))
        #expect(catalog.cullError == nil)

        var rated = catalog
        rated.select([])
        rated.open(order[0])
        var rejected = catalog
        rejected.select([order[1]])
        let ratedMetadata = try #require(rated.selectedMetadata)
        let rejectedMetadata = try #require(rejected.selectedMetadata)
        let value = try #require(rated.loupeValue)
        #expect(value.hasSuffix("3 stars, Picked, Red label"), "the loupe's value reads \(value)")
        let readout = try #require(rated.loupeReadout)
        #expect(readout.hasSuffix("  ·  3 stars, Picked, Red label"), "the loupe's readout reads \(readout)")
        #expect(ratedMetadata.title == rated.loupeItem?.name)
        #expect(ratedMetadata.rating == .value(3) && ratedMetadata.flag == .value(.pick))
        #expect(ratedMetadata.label == .value(.red))
        #expect(rejectedMetadata.flag == .value(.reject))

        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                page(rated, other: rejectedMetadata),
                name: "library-rated-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// The loupe on the left; the window's inspector for it and the other photo's on the right.
    private func page(_ model: LibraryCatalog, other: PhotoMetadata) -> some View {
        HStack(alignment: .top, spacing: 0) {
            LibraryBrowser(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: SuiteSpacing.m) {
                LibraryInspector(model: model)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 400, alignment: .topLeading)
                    .background(SuiteColor.panel)
                MetadataInspector(metadata: other)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 360, alignment: .topLeading)
                    .background(SuiteColor.panel)
            }
            .padding(SuiteSpacing.l)
        }
    }
}
