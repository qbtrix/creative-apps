// LibraryCollectionSwitchTests.swift: what choosing a collection does to the
// selection and the loupe in LibraryCatalog (#156). Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import LibraryModel
import Testing

/// A picked photo "A" and an unpicked photo "B", so Favorites shows only A.
private func pickedAndUnpicked() -> LibraryCatalog {
    let date = Date(timeIntervalSince1970: 0)
    var catalog = LibraryCatalog()
    catalog.load([
        PhotoItem(name: "A", captureDate: date, color: Color3(0, 0, 0), isFlagged: true),
        PhotoItem(name: "B", captureDate: date.addingTimeInterval(60), color: Color3(0, 0, 0)),
    ])
    return catalog
}

@Test func switchingToACollectionWithoutTheFocusedPhotoReturnsToTheGrid() {
    var catalog = pickedAndUnpicked()
    catalog.open("B")
    catalog.selectCollection("favorites")
    #expect(catalog.mode == .grid && catalog.focusedItemID == nil)
    #expect(catalog.selection.isEmpty)
}

@Test func switchingToACollectionThatShowsTheFocusedPhotoStaysInTheLoupe() {
    var catalog = pickedAndUnpicked()
    catalog.open("A")
    catalog.selectCollection("favorites")
    #expect(catalog.mode == .loupe && catalog.focusedItemID == "A")
    catalog.selectCollection("recent")
    #expect(catalog.mode == .loupe && catalog.focusedItemID == "A")
}

@Test func switchingCollectionKeepsOnlyShownIdsSelected() {
    var catalog = pickedAndUnpicked()
    catalog.select(["A", "B"])
    catalog.selectCollection("favorites")
    #expect(catalog.selection.isSubset(of: Set(catalog.sortedItems.map(\.id))))
    catalog.selectCollection("trash")
    #expect(catalog.selectedCollectionID == "favorites")
}
