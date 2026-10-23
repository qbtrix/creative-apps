// LibraryMetadataSlotsTests.swift (metadata-more MD-4): the slots later
// slices fill exist, the real parts of them work now (`keywordHelp`, an
// empty `PhotoSearch`, the identifiers), and the inert parts change nothing.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import LibraryModel
import Testing

/// Two photos with keywords, a title and a caption, nothing selected.
private func twoPhotos() -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.load((1...2).map {
        PhotoItem(
            name: "P\($0)", captureDate: Date(timeIntervalSince1970: 1_767_225_600), color: Color3(0, 0, 0),
            keywords: ["Beach"], title: "Harbour", caption: "Morning \($0)")
    })
    return catalog
}

@Test func keywordHelpAsksForASelectionUntilThereIsOne() {
    var catalog = twoPhotos()
    #expect(catalog.keywordHelp == "Select a photo to add keywords.")
    catalog.select(["P1"])
    #expect(catalog.keywordHelp == nil)
}

@Test func aBlankSearchIsEmptyAndMatchesEverything() {
    let blank = PhotoSearch("  ")
    #expect(blank.isEmpty)
    #expect(PhotoSearch("").isEmpty)
    #expect(!PhotoSearch("beach").isEmpty)
    #expect(PhotoSearch("beach").text == "beach")
    #expect(twoPhotos().items.allSatisfy(blank.matches))
}

@Test func theInertSlotsChangeNothing() {  // keywords are real since MD-10, title and caption since MD-11
    var catalog = twoPhotos()
    catalog.select(["P1", "P2"])
    #expect(catalog.sidecarWrites(after: [:]).isEmpty)
    #expect(catalog.sidecarStatus(for: "P1", written: [:], failures: [:], writing: [])
        == "Samples have no file, so no sidecar.")
}

@Test func theInspectorReadsTitleAndCaptionAcrossTheSelection() {
    var catalog = twoPhotos()
    catalog.select(["P1", "P2"])
    #expect(catalog.selectedMetadata?.photoTitle == .value("Harbour"))
    #expect(catalog.selectedMetadata?.caption == .mixed)
}

@Test func everyNewIdentifierIsUniqueAndLibraryScoped() {
    let ids = [
        MetadataInspectorID.keywordsField, MetadataInspectorID.keyword("Beach"),
        MetadataInspectorID.removeKeyword("Beach"), MetadataInspectorID.keyword("Sunset"),
        MetadataInspectorID.removeKeyword("Sunset"), MetadataInspectorID.title, MetadataInspectorID.caption,
        MetadataInspectorID.sidecar, MetadataInspectorID.search,
    ]
    let existing = [MetadataInspectorID.flag, MetadataInspectorID.label(nil)] + (1...5).map(MetadataInspectorID.star)
        + CameraField.allCases.map(MetadataInspectorID.camera) + PhotoFlag.allCases.map(MetadataInspectorID.flag)
    #expect(Set(ids).count == ids.count)
    #expect(Set(ids).isDisjoint(with: existing))
    #expect(ids.allSatisfy { $0.hasPrefix("library.") })
    #expect(MetadataInspectorID.search == "library.search")
    #expect(MetadataInspectorID.keyword("Beach") == MetadataInspectorID.keyword("beach"))
}
