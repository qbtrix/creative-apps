// LibraryCollectionSwitchTests.swift: what choosing a collection does to the
// loupe and the selection (#156). Runs on Linux and macOS.
import LibraryModel
import Testing

@Suite struct LibraryCollectionSwitchTests {
    private func samples() -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        return catalog
    }

    @Test func choosingACollectionThatHidesTheLoupePhotoReturnsToTheGrid() throws {
        var catalog = samples()
        let unflagged = try #require(catalog.sortedItems.first { !$0.isFlagged })
        catalog.open(unflagged.id)
        #expect(catalog.mode == .loupe)
        catalog.selectCollection("favorites")
        #expect(catalog.mode == .grid)
        #expect(catalog.focusedItemID == nil)
        #expect(catalog.selection.isEmpty)
    }

    @Test func choosingACollectionThatStillShowsTheLoupePhotoKeepsTheLoupe() throws {
        var catalog = samples()
        let flagged = try #require(catalog.sortedItems.first { $0.isFlagged })
        catalog.open(flagged.id)
        catalog.selectCollection("favorites")
        #expect(catalog.mode == .loupe)
        #expect(catalog.focusedItemID == flagged.id)
        catalog.selectCollection("all")
        #expect(catalog.mode == .loupe)
        #expect(catalog.focusedItemID == flagged.id)
    }

    @Test func anUnknownCollectionChangesNothing() throws {
        var catalog = samples()
        let first = try #require(catalog.sortedItems.first)
        catalog.open(first.id)
        catalog.selectCollection("trash")
        #expect(catalog.selectedCollectionID == "all")
        #expect(catalog.mode == .loupe)
        #expect(catalog.focusedItemID == first.id)
    }
}
