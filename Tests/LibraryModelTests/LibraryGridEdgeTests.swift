// LibraryGridEdgeTests.swift: edge cases for the photo grid's state in
// LibraryCatalog: sample data shape, sort orders over the samples, selection
// across sorts and reloads, and the counts with fewer than twenty photos.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import LibraryModel
import Testing

private func photo(_ name: String, minute: Double, rating: Int = 0, flagged: Bool = false) -> PhotoItem {
    PhotoItem(
        name: name, captureDate: Date(timeIntervalSince1970: minute * 60), color: Color3(0, 0, 0), rating: rating,
        isFlagged: flagged)
}

@Test(arguments: [0, 1, 2026, UInt64.max])
func samplesAreWellFormedForAnySeed(seed: UInt64) {
    let items = LibrarySample.items(seed: seed)
    let expectedNames: [String] = (1...60).map { (n: Int) -> String in
        let digits = String(n)
        let padding = String(repeating: "0", count: 4 - digits.count)
        return "IMG_" + padding + digits
    }
    let names: [String] = items.map(\.name)
    #expect(names == expectedNames)
    let start = Date(timeIntervalSince1970: 1_767_225_600)
    let end = start.addingTimeInterval(365 * 24 * 60 * 60)
    #expect(items.allSatisfy { (0...5).contains($0.rating) && $0.captureDate >= start && $0.captureDate < end })
    #expect(items.allSatisfy { [$0.color.c0, $0.color.c1, $0.color.c2].allSatisfy { (0...1).contains($0) } })
    #expect(items.allSatisfy { $0.pixel.count == 4 && $0.pixel[3] == 255 })
}

@Test func defaultSamplesHaveEveryBadgeKind() {
    let items = LibrarySample.items()
    #expect(items.contains(where: \.isFlagged) && items.contains { !$0.isFlagged })
    #expect(Set(items.map(\.rating)).count > 1)
    #expect(items.contains { $0.label == nil } && items.contains { $0.label != nil })
}

@Test(arguments: LibrarySort.allCases)
func everySortShowsEachSamplePhotoOnceInATotalOrder(sort: LibrarySort) {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.setSort(sort)
    let shown = catalog.sortedItems
    #expect(Set(shown.map(\.id)) == Set(catalog.items.map(\.id)) && shown.count == 60)
    var reloaded = catalog
    reloaded.load(catalog.items.reversed())
    #expect(reloaded.sortedItems == shown)
}

@Test func favoritesAndRecentAreSortedAndMatchTheirCounts() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    for collection in catalog.collections {
        catalog.selectCollection(collection.id)
        catalog.setSort(.name)
        #expect(catalog.sortedItems.count == collection.count)
        #expect(catalog.sortedItems.map(\.name) == catalog.sortedItems.map(\.name).sorted())
    }
    catalog.selectCollection("favorites")
    #expect(catalog.sortedItems.allSatisfy { $0.isFlagged })
}

@Test func recentCountsAllPhotosWhenFewerThanTheLimit() {
    var catalog = LibraryCatalog()
    catalog.load((1...3).map { photo("P\($0)", minute: Double($0), flagged: $0 == 2) })
    #expect(catalog.collections.map(\.count) == [3, 1, 3])
    catalog.load([])
    #expect(catalog.isEmpty && catalog.collections.map(\.count) == [0, 0, 0] && catalog.sortedItems.isEmpty)
}

@Test func selectionSurvivesSortingAndClearsOnReload() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.select(["IMG_0003", "IMG_0010"])
    catalog.setSort(.rating)
    #expect(catalog.selection == ["IMG_0003", "IMG_0010"])
    catalog.open("IMG_0003")
    catalog.loadSamples()
    #expect(catalog.selection.isEmpty && catalog.mode == .grid && catalog.focusedItemID == nil)
}

@Test func selectionAndOpenIgnorePhotosOutsideTheCollection() {
    var catalog = LibraryCatalog()
    catalog.load([photo("A", minute: 1, flagged: true), photo("B", minute: 2)])
    catalog.selectCollection("favorites")
    catalog.select(["A", "B"])
    #expect(catalog.selection == ["A"])
    catalog.open("B")
    #expect(catalog.mode == .grid && catalog.focusedItemID == nil)
    catalog.selectCollection("nope")
    #expect(catalog.selectedCollectionID == "favorites" && catalog.selection == ["A"])
}

@Test func cellSizeStepsByForty() {
    var catalog = LibraryCatalog()
    var sizes = [catalog.cellSize]
    for _ in 0..<8 {
        catalog.stepCellSize(by: -1)
        sizes.append(catalog.cellSize)
    }
    #expect(sizes == [160, 120, 80, 80, 80, 80, 80, 80, 80])
    catalog.stepCellSize(by: 0)
    #expect(catalog.cellSize == 80 && catalog.canShowLargerThumbnails)
}
