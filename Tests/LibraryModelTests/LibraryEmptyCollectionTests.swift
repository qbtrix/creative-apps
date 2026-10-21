// LibraryEmptyCollectionTests.swift: an empty collection's copy says how to fill it.
import LibraryModel
import Testing

@Suite struct LibraryEmptyCollectionTests {
    private func collection(_ id: String) -> LibraryCollection? {
        LibraryCatalog().collections.first { $0.id == id }
    }

    /// One word for a pick everywhere (#3639): the collection is Picks and its copy says Pick, never Favorites or Flagged.
    @Test func picksSaysToPickAPhoto() {
        let picks = collection("favorites")
        #expect(picks?.name == "Picks")
        #expect(picks?.emptyMessage.contains("Pick a photo") == true)
        #expect(picks?.emptyMessage.contains("Favorites") == false)
        #expect(picks?.emptyMessage.contains("Flagged") == false)
        #expect(picks?.emptyActionTitle == "Show All Photos")
    }

    @Test func everyCollectionSaysHowToFillIt() {
        for collection in LibraryCatalog().collections {
            #expect(collection.emptyMessage.contains("appear here"))
            #expect(collection.emptyMessage.contains("Pick") || collection.emptyMessage.contains("Import"))
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
