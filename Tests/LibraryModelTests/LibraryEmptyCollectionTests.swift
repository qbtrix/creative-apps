// LibraryEmptyCollectionTests.swift: an empty collection's copy says how to fill it.
import LibraryModel
import Testing

@Suite struct LibraryEmptyCollectionTests {
    private func collection(_ id: String) -> LibraryCollection? {
        LibraryCatalog().collections.first { $0.id == id }
    }

    @Test func favoritesSaysToFlagAPhoto() {
        let favorites = collection("favorites")
        #expect(favorites?.emptyMessage.contains("Flag a photo") == true)
        #expect(favorites?.emptyActionTitle == "Show All Photos")
    }

    @Test func everyCollectionSaysHowToFillIt() {
        for collection in LibraryCatalog().collections {
            #expect(collection.emptyMessage.contains("appear here"))
            #expect(collection.emptyMessage.contains("Flag") || collection.emptyMessage.contains("Import"))
        }
    }

    @Test func allPhotosHasNoShowAllButton() {
        #expect(collection("all")?.emptyActionTitle == nil)
        #expect(collection("recent")?.emptyActionTitle == "Show All Photos")
    }

    @Test func theActionReachesAllPhotos() {
        var catalog = LibraryCatalog()
        catalog.load(LibrarySample.items().filter { !$0.isFlagged })
        catalog.selectCollection("favorites")
        #expect(catalog.isSelectedCollectionEmpty)
        catalog.selectCollection("all")
        #expect(!catalog.isSelectedCollectionEmpty)
    }
}
