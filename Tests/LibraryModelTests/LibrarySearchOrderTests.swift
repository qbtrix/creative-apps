// LibrarySearchOrderTests.swift: MD-21 (metadata-more), how the search field
// shapes the catalog on the `cameras` fixture. A search keeps only matching
// ids in `order` and drops hidden ids from the selection; a loupe on a photo
// the search hides goes back to the grid with nothing focused; an empty
// search shows every photo; under `keyword:beach` removing Beach from a shown
// photo hides it; with no search a keyword edit leaves `order` alone; and the
// search is part of `==`. Written before its code (rule 13, MD-19): every test
// waits on MD-21. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

/// Stand-in until MD-21 adds `LibraryCatalog.setSearch(_:)`: it does nothing,
/// so these files build on the slots. MD-21 deletes it with the traits.
extension LibraryCatalog {
    @_disfavoredOverload mutating func setSearch(_ text: String) {}
}

/// The `cameras` id of `IMG_n`.
private func camerasID(_ n: Int) -> String { "/fixture/cameras/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }

/// The 24 `cameras` photos, loaded.
private func camerasCatalog() -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.load(LibraryFixtures.photos(named: "cameras"))
    return catalog
}

/// The `cameras` ids in `order`, as their numbers, sorted.
private func shown(_ catalog: LibraryCatalog) -> [Int] {
    catalog.order.compactMap { id in (1...24).first { camerasID($0) == id } }.sorted()
}

@Test(.disabled("waits on MD-21")) func searchNarrowsOrderAndSelection() {
    var catalog = camerasCatalog()
    catalog.select([camerasID(2), camerasID(3)])
    catalog.setSearch("lens:50")
    #expect(catalog.order.count == 8)
    #expect(shown(catalog) == [2, 5, 8, 11, 14, 17, 20, 23])
    // IMG_0003 is on the macro: hidden, so no longer selected.
    #expect(catalog.selection == [camerasID(2)])
}

@Test(.disabled("waits on MD-21")) func searchThatHidesTheLoupePhotoReturnsToTheGrid() {
    var catalog = camerasCatalog()
    catalog.open(camerasID(2))
    #expect(catalog.mode == .loupe)
    catalog.setSearch("lens:24")
    #expect(catalog.mode == .grid)
    #expect(catalog.focusedItemID == nil)
    #expect(catalog.selection.isEmpty)
    #expect(shown(catalog) == [1, 4, 7, 10, 13, 16, 19, 22])
}

@Test(.disabled("waits on MD-21")) func searchThatKeepsTheLoupePhotoStaysInTheLoupe() {
    var catalog = camerasCatalog()
    catalog.open(camerasID(2))
    catalog.setSearch("lens:50")
    #expect(catalog.mode == .loupe)
    #expect(catalog.focusedItemID == camerasID(2))
}

@Test(.disabled("waits on MD-21")) func emptySearchShowsEveryPhoto() {
    var catalog = camerasCatalog()
    let all = catalog.order
    catalog.setSearch("iso:>1600 beach")
    #expect(shown(catalog) == [13, 14])
    catalog.setSearch("")
    #expect(catalog.order == all)
    #expect(catalog.order.count == 24)
}

@Test(.disabled("waits on MD-21")) func removingTheSearchedKeywordHidesThePhoto() {
    var catalog = camerasCatalog()
    catalog.setSearch("keyword:beach")
    #expect(shown(catalog) == [1, 2, 3, 4, 13, 14])
    catalog.recordEdit("Remove Keyword", ids: [camerasID(13)]) { $0.keywords.removeAll { $0 == "Beach" } }
    #expect(shown(catalog) == [1, 2, 3, 4, 14])
    catalog.undo()
    #expect(shown(catalog) == [1, 2, 3, 4, 13, 14])
}

@Test(.disabled("waits on MD-21")) func keywordEditWithoutSearchLeavesOrderAlone() {
    var catalog = camerasCatalog()
    // A sentinel order no rebuild would make: if the edit rebuilt `order`,
    // the sort would put it back.
    let sentinel = Array(catalog.order.reversed())
    catalog.order = sentinel
    catalog.recordEdit("Add Keyword", ids: [camerasID(5)]) { $0.keywords.append("Harbour") }
    catalog.recordEdit("Remove Keyword", ids: [camerasID(1)]) { $0.keywords.removeAll { $0 == "Beach" } }
    #expect(catalog.history.undo.count == 2)
    #expect(catalog.order == sentinel)
}

@Test(.disabled("waits on MD-21")) func catalogsDifferingOnlyInSearchAreNotEqual() {
    let a = camerasCatalog()
    var b = camerasCatalog()
    // Every name holds "img", so `order` is the same and only the search differs.
    b.setSearch("img")
    #expect(b.order == a.order)
    #expect(a != b)
    b.setSearch("")
    #expect(a == b)
}
