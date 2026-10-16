// LibraryRatingSnapshots.swift: the cull feature's result (cull CU-5): the
// loupe on a sample photo culled to 3 stars, picked and red, beside the
// MetadataInspector for that photo and for a second, rejected photo, with
// the loupe's value written under them. Built only through the catalog's
// public cull methods, in Light and Dark. Writes library-rated-{light,dark}.png.
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
        rated.select([order[0]])
        rated.open(order[0])
        var rejected = catalog
        rejected.select([order[1]])
        let ratedMetadata = try #require(rated.selectedMetadata)
        let rejectedMetadata = try #require(rejected.selectedMetadata)
        let value = try #require(rated.loupeValue)
        #expect(value.hasSuffix("3 stars, Picked, Red"), "the loupe's value reads \(value)")
        #expect(ratedMetadata.rating == .value(3) && ratedMetadata.flag == .value(.pick))
        #expect(ratedMetadata.label == .value(.red))
        #expect(rejectedMetadata.flag == .value(.reject))

        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                page(rated, value: value, inspectors: [ratedMetadata, rejectedMetadata]),
                name: "library-rated-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// The loupe on the left; the two inspectors and the loupe's value on the right.
    private func page(_ model: LibraryCatalog, value: String, inspectors: [PhotoMetadata]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            LibraryBrowser(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: SuiteSpacing.m) {
                ForEach(inspectors, id: \.title) { metadata in
                    MetadataInspector(metadata: metadata)
                        .frame(width: SuiteSize.inspectorWidth.ideal, height: 360, alignment: .topLeading)
                        .background(SuiteColor.panel)
                }
                Text(value)
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.textSecondary)
                    .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .leading)
            }
            .padding(SuiteSpacing.l)
        }
    }
}
