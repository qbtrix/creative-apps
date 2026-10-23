// LibraryMetadataSnapshots.swift: Library's MetadataInspector for one rated,
// picked, blue-labelled sample photo, and for three photos with mixed ratings,
// flags and labels, in Light and Dark. Flag is three ChoiceChips (#3637). Writes library-metadata-{light,dark}.png and
// library-metadata-mixed-{light,dark}.png. At the ideal inspector width the
// mixed panel is as tall as the single one: "Mixed" never wraps (#1719).
// macOS only.
import AppKit
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
        one.setFlag(.pick)
        one.setLabel(.blue)
        mixed.select(Set(order.prefix(3)))
        mixed.setRating(2)
        mixed.select(Set(order.prefix(1)))
        mixed.setRating(5)
        mixed.setFlag(.reject)
        mixed.setLabel(.red)
        mixed.select(Set(order.prefix(3)))
        let single = try #require(one.selectedMetadata)
        let several = try #require(mixed.selectedMetadata)
        #expect(single.rating == .value(4) && single.label == .value(.blue))
        #expect(several.rating == .mixed && several.label == .mixed && several.title == "3 Photos")
        #expect(single.flag == .value(.pick) && several.flag == .mixed)
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(panel(single), name: "library-metadata-\(suffix)", scheme: scheme)
            try snapshot(panel(several), name: "library-metadata-mixed-\(suffix)", scheme: scheme)
        }
    }

    /// Flag is one chip per PhotoFlag, each with its own identifier; the shared flag's chip is on, none while mixed.
    @Test func flagIsThreeChips() throws {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        let order = catalog.sortedItems.map(\.id)
        catalog.select(Set(order.prefix(1)))
        catalog.setFlag(.pick)
        let picked = try #require(catalog.selectedMetadata)
        catalog.select(Set(order.prefix(2)))
        let mixed = try #require(catalog.selectedMetadata)
        let options = MetadataInspector.flagOptions
        #expect(options.map(\.id) == PhotoFlag.allCases)
        #expect(options.map(\.title) == ["None", "Pick", "Reject"])
        #expect(options.map(\.identifier) == PhotoFlag.allCases.map(MetadataInspectorID.flag))
        #expect(picked.flag.shared == .pick && mixed.flag == .mixed && mixed.flag.shared == nil)
        // Every chip's title fits its column at the ideal inspector width (one line, no "…").
        let font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        let widest = options.map { ($0.title as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        let label = ("Flag" as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width
        let chips = SuiteSize.inspectorWidth.ideal - 4 * SuiteSpacing.m - label - SuiteSpacing.s
        #expect(widest + 2 * SuiteSpacing.xs <= (chips - 2 * SuiteSpacing.xs) / 3, "a flag chip is too narrow")
    }

    @Test func mixedRowsKeepOneLineHeight() throws {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        let order = catalog.sortedItems.map(\.id)
        catalog.select(Set(order.prefix(1)))
        let single = try #require(catalog.selectedMetadata)
        catalog.setRating(3)
        catalog.setLabel(.green)
        catalog.select(Set(order.prefix(3)))
        let several = try #require(catalog.selectedMetadata)
        #expect(several.rating == .mixed && several.label == .mixed)
        let width = SuiteSize.inspectorWidth.ideal
        let one = fitting(MetadataInspector(metadata: single), width: width)
        let many = fitting(MetadataInspector(metadata: several), width: width)
        #expect(abs(many.height - one.height) < 0.5, "mixed is \(many.height) pt tall, single \(one.height) pt")
        #expect(many.width <= width + 0.5, "mixed is \(many.width) pt wide")
    }

    private func fitting(_ view: some View, width: CGFloat) -> CGSize {
        let host = NSHostingView(rootView: view.frame(width: width))
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    private func panel(_ metadata: PhotoMetadata) -> some View {
        MetadataInspector(metadata: metadata)
            .frame(width: SuiteSize.inspectorWidth.ideal, height: 900, alignment: .topLeading)
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
    }
}
