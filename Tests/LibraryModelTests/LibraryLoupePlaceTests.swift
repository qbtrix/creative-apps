// LibraryLoupePlaceTests.swift: the loupe readouts (loupeItem, loupePosition,
// canShowPrevious/NextInLoupe) read `order` and `items` directly (loupe-viewport
// LV-6) and still agree with the sorted list in every collection and sort, and
// an id the loupe can't find shows nothing. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

/// The readouts the sorted list gives for the photo at `index`.
private func expectMatchesSortedList(_ catalog: LibraryCatalog, at index: Int) {
    let sorted = catalog.sortedItems
    #expect(catalog.loupeItem == sorted[index])
    #expect(catalog.loupePosition == "\(index + 1) of \(sorted.count)")
    #expect(catalog.canShowPreviousInLoupe == (index > 0))
    #expect(catalog.canShowNextInLoupe == (index < sorted.count - 1))
}

@Test(arguments: LibrarySort.allCases, ["all", "favorites", "recent"])
func readoutsAgreeWithTheSortedList(sort: LibrarySort, collection: String) {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.setSort(sort)
    catalog.selectCollection(collection)
    let ids = catalog.sortedItems.map(\.id)
    #expect(ids == catalog.order)
    for index in Set([0, ids.count / 2, ids.count - 1]).sorted() where ids.indices.contains(index) {
        catalog.open(ids[index])
        expectMatchesSortedList(catalog, at: index)
    }
}

@Test func aFocusedIDWithNoPhotoShowsNothing() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.open(catalog.order[3])
    catalog.order.insert("ghost", at: 0)
    catalog.focusedItemID = "ghost"
    #expect(catalog.loupeItem == nil)
    #expect(catalog.loupePosition == nil)
    #expect(!catalog.canShowPreviousInLoupe && !catalog.canShowNextInLoupe)
}

@Test func theGridShowsNoLoupeReadouts() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.open(catalog.order[3])
    catalog.showGrid()
    #expect(catalog.loupeItem == nil && catalog.loupePosition == nil)
    #expect(!catalog.canShowPreviousInLoupe && !catalog.canShowNextInLoupe)
}
