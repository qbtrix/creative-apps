// MetadataInspectorIDTests.swift: the metadata inspector's identifiers are
// in Library's scheme and unique, a Flag chip's included. Runs on Linux and macOS.
import LibraryModel
import Testing

@Test func metadataInspectorIdentifiersAreUniqueAndInLibrarysScheme() {
    let labels = ([nil] + PhotoLabel.allCases.map { $0 }).map(MetadataInspectorID.label)
    let flags = PhotoFlag.allCases.map(MetadataInspectorID.flag)
    let all = [MetadataInspectorID.flag] + flags + (1...5).map(MetadataInspectorID.star) + labels
    #expect(Set(all).count == all.count)
    #expect(all.allSatisfy { $0.hasPrefix("library.metadata.") })
    #expect(MetadataInspectorID.star(4) == "library.metadata.star.4")
    #expect(MetadataInspectorID.label(.red) == "library.metadata.label.red")
    #expect(MetadataInspectorID.label(nil) == "library.metadata.label.none")
    #expect(MetadataInspectorID.flag(.pick) == "library.metadata.flag.pick")
    #expect(MetadataInspectorID.flag(.none) == "library.metadata.flag.none")
}
