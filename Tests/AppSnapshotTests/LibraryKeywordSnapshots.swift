// LibraryKeywordSnapshots.swift: keywords, title and caption in the Info tab (metadata-more MD-13), shared
// (`library-keywords`) and partial with a "Mixed" title (`library-keywords-mixed`). Written first (MD-9).
import AppKit
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

@MainActor
@Suite struct LibraryKeywordSnapshots {
    private func two(_ photos: [(keywords: [String], title: String)]) -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        let samples = catalog.sortedItems.prefix(2)
        catalog.load(zip(samples, photos).map { sample, photo in
            PhotoItem(
                name: sample.name, captureDate: sample.captureDate, color: sample.color, keywords: photo.keywords,
                title: photo.title, caption: photo.title.isEmpty ? "" : "Low tide")
        })
        catalog.services.isPreview = false
        catalog.select(Set(catalog.items.map(\.id)))
        return catalog
    }

    @Test(.disabled("waits on MD-13")) func sharedKeywords() throws {
        let catalog = two([(["Beach", "Sunset"], "Harbour at dawn"), (["Beach", "Sunset"], "Harbour at dawn")])
        #expect(catalog.keywordStates.allSatisfy { !$0.isPartial })
        #expect(catalog.selectedMetadata?.photoTitle == .value("Harbour at dawn"))
        try shoot(catalog, "library-keywords")
    }

    @Test(.disabled("waits on MD-13")) func partialKeywordsAndMixedTitle() throws {
        let catalog = two([(["Beach", "Sunset"], "Harbour at dawn"), (["Beach"], "")])
        #expect(catalog.keywordStates.map(\.isPartial) == [false, true])
        #expect(catalog.selectedMetadata?.photoTitle == .mixed)
        try shoot(catalog, "library-keywords-mixed")
    }

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
