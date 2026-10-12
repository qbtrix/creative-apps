// LibraryGridTests.swift: the photo grid's state in LibraryCatalog: seeded
// samples, sorting, cell size, counts, selection and opening into the loupe.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import LibraryModel
import Testing

private func photo(_ name: String, minute: Double, rating: Int = 0, color: Color3 = Color3(0, 0, 0)) -> PhotoItem {
    PhotoItem(name: name, captureDate: Date(timeIntervalSince1970: minute * 60), color: color, rating: rating)
}

@Test func sameSeedGivesSameSixtyItems() {
    let items = LibrarySample.items(seed: 7)
    #expect(items == LibrarySample.items(seed: 7) && items != LibrarySample.items(seed: 8))
    #expect(items.count == 60 && Set(items.map(\.id)).count == 60)
    #expect(items.first?.name == "IMG_0001" && items.last?.name == "IMG_0060")
    let clamped = photo("X", minute: 0, rating: 9, color: Color3(1, 0.5, -2))
    #expect(clamped.pixel == [255, 128, 0, 255] && clamped.rating == 5)
}

@Test func countsFollowTheItemsAndRecentIsTheTwentyNewest() {
    var catalog = LibraryCatalog()
    catalog.loadSamples(seed: 7)
    let picks = LibrarySample.items(seed: 7).filter(\.isFlagged).count
    #expect(picks > 0 && !catalog.isEmpty)
    #expect(catalog.collections.map(\.count) == [60, picks, 20])
    catalog.load((1...25).map { photo("P\($0)", minute: Double($0)) })
    catalog.selectCollection("recent")
    #expect(catalog.sortedItems.map(\.name) == (6...25).map { "P\($0)" })
}

@Test func eachSortKeepsTiesInNameOrder() {
    var catalog = LibraryCatalog()
    catalog.load([
        photo("C", minute: 5, rating: 2), photo("A", minute: 5, rating: 4),
        photo("B", minute: 1, rating: 2), photo("D", minute: 9, rating: 4),
    ])
    #expect(catalog.sortedItems.map(\.name) == ["B", "A", "C", "D"])
    catalog.setSort(.name)
    #expect(catalog.sortedItems.map(\.name) == ["A", "B", "C", "D"])
    catalog.setSort(.rating)
    #expect(catalog.sortedItems.map(\.name) == ["A", "D", "B", "C"])
}

@Test func cellSizeStepsAndClampsTo80Through320() {
    var catalog = LibraryCatalog()
    catalog.stepCellSize(by: 1)
    #expect(catalog.cellSize == 200)
    catalog.stepCellSize(by: 10)
    #expect(catalog.cellSize == 320 && !catalog.canShowLargerThumbnails)
    catalog.stepCellSize(by: -20)
    #expect(catalog.cellSize == 80 && !catalog.canShowSmallerThumbnails)
}

@Test func openingSetsLoupeModeWithThatItemFocused() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.open("nope")
    #expect(catalog.mode == .grid && catalog.focusedItemID == nil)
    catalog.open("IMG_0012")
    #expect(catalog.mode == .loupe && catalog.focusedItemID == "IMG_0012")
}

@Test func switchingCollectionClearsTheSelection() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.select(["IMG_0001", "missing"])
    #expect(catalog.selection == ["IMG_0001"])
    catalog.selectCollection("favorites")
    #expect(catalog.selection.isEmpty)
}
