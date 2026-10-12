// LibraryCatalogTests.swift: behavior of LibraryCatalog, the state behind
// Library's window. Runs on Linux and macOS.
import LibraryModel
import Testing

@Test func startsEmptyOnAllPhotos() {
    let catalog = LibraryCatalog()
    #expect(catalog.isEmpty)
    #expect(catalog.collections.map(\.name) == ["All Photos", "Favorites", "Recently Added"])
    #expect(catalog.selectedCollection?.id == "all")
}

@Test func selectsKnownCollectionsOnly() {
    var catalog = LibraryCatalog()
    catalog.selectCollection("favorites")
    #expect(catalog.selectedCollectionID == "favorites")
    catalog.selectCollection("trash")
    #expect(catalog.selectedCollectionID == "favorites")
}
