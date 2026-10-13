// LibraryCollectionEmptinessTests.swift: adversarial and seeded fuzz tests for
// LibraryCatalog.isSelectedCollectionEmpty (#157). Random catalogs across every
// collection and sort, reloads under a selected collection, and the grid
// actions on an empty collection. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import LibraryModel
import Testing

/// A tiny deterministic generator (64-bit LCG, high bits out) so a failing catalog replays.
private struct CatalogRNG: RandomNumberGenerator {
    var seed: UInt64

    mutating func next() -> UInt64 {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return seed ^ (seed >> 29)
    }
}

private let collectionIDs = ["all", "favorites", "recent"]

private func photo(_ index: Int, flagged: Bool = false, rating: Int = 0, day: Int = 0) -> PhotoItem {
    PhotoItem(
        name: "P\(index)", captureDate: Date(timeIntervalSince1970: Double(day) * 86_400),
        color: Color3(0.5, 0.5, 0.5), rating: rating, isFlagged: flagged)
}

/// Every emptiness signal the browser could read agrees for the selected collection.
private func expectConsistent(_ catalog: LibraryCatalog, _ context: String) {
    let count = catalog.selectedCollection?.count ?? -1
    #expect(catalog.isSelectedCollectionEmpty == catalog.sortedItems.isEmpty, "\(context)")
    #expect(catalog.isSelectedCollectionEmpty == (count == 0), "\(context), count \(count)")
    if catalog.isEmpty { #expect(catalog.isSelectedCollectionEmpty, "\(context)") }
}

@Test(arguments: collectionIDs)
func everyCollectionOfAnEmptyCatalogIsEmpty(id: String) {
    var catalog = LibraryCatalog()
    catalog.selectCollection(id)
    expectConsistent(catalog, id)
    #expect(catalog.isSelectedCollectionEmpty)
    catalog.load([])
    #expect(catalog.isEmpty && catalog.isSelectedCollectionEmpty)
}

@Test func recentlyAddedIsEmptyOnlyWhenTheCatalogIs() {
    var catalog = LibraryCatalog()
    catalog.selectCollection("recent")
    for size in [1, 2, LibraryCatalog.recentLimit, LibraryCatalog.recentLimit + 1, 100] {
        catalog.load((0..<size).map { photo($0, day: size - $0) })
        #expect(!catalog.isSelectedCollectionEmpty, "size \(size)")
        expectConsistent(catalog, "size \(size)")
    }
}

@Test func favoritesWithOneFlaggedPhotoIsNotEmpty() {
    var catalog = LibraryCatalog()
    catalog.selectCollection("favorites")
    catalog.load((0..<50).map { photo($0, flagged: $0 == 49) })
    #expect(!catalog.isSelectedCollectionEmpty && catalog.sortedItems.map(\.id) == ["P49"])
    catalog.load((0..<50).map { photo($0) })
    #expect(catalog.isSelectedCollectionEmpty)
    expectConsistent(catalog, "no picks")
}

@Test func reloadingUnderASelectedCollectionUpdatesItsEmptiness() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.selectCollection("favorites")
    #expect(!catalog.isSelectedCollectionEmpty)
    catalog.load(LibrarySample.items().filter { !$0.isFlagged })
    #expect(catalog.selectedCollectionID == "favorites" && catalog.isSelectedCollectionEmpty)
    catalog.loadSamples()
    #expect(!catalog.isSelectedCollectionEmpty)
    catalog.load([])
    #expect(catalog.isEmpty && catalog.isSelectedCollectionEmpty)
}

@Test func sortingNeverChangesEmptiness() {
    var catalog = LibraryCatalog()
    catalog.load([photo(0, rating: 5), photo(1, rating: 1)])
    for id in collectionIDs {
        catalog.selectCollection(id)
        let empty = catalog.isSelectedCollectionEmpty
        for sort in LibrarySort.allCases {
            catalog.setSort(sort)
            #expect(catalog.isSelectedCollectionEmpty == empty, "\(id), \(sort)")
        }
    }
}

@Test func gridActionsOnAnEmptyCollectionDoNothing() {
    var catalog = LibraryCatalog()
    catalog.load((0..<5).map { photo($0) })
    catalog.selectCollection("favorites")
    #expect(catalog.isSelectedCollectionEmpty)
    let before = catalog
    catalog.select(Set((0..<5).map { "P\($0)" }))
    catalog.open("P0")
    #expect(catalog == before)
    #expect(catalog.selection.isEmpty && catalog.mode == .grid && catalog.focusedItemID == nil)
}

@Test(arguments: [UInt64(1), 42, 157, 0xC0FF_EE00])
func seededRandomCatalogsAgreeOnEmptiness(seed: UInt64) {
    var rng = CatalogRNG(seed: seed)
    for round in 0..<300 {
        let size = Int.random(in: 0...30, using: &rng)
        let flagRate = Int.random(in: 0...3, using: &rng)  // 0: no picks at all
        let photos = (0..<size).map {
            photo(
                $0, flagged: flagRate > 0 && Int.random(in: 0..<4, using: &rng) < flagRate,
                rating: Int.random(in: -2...7, using: &rng), day: Int.random(in: -400...400, using: &rng))
        }
        var catalog = LibraryCatalog()
        catalog.selectCollection(collectionIDs.randomElement(using: &rng) ?? "all")
        catalog.load(photos)
        catalog.setSort(LibrarySort.allCases.randomElement(using: &rng) ?? .name)
        for id in collectionIDs {
            catalog.selectCollection(id)
            let context = "seed \(seed), round \(round), \(id), size \(size)"
            expectConsistent(catalog, context)
            let expected = id == "favorites" ? !photos.contains(where: \.isFlagged) : photos.isEmpty
            #expect(catalog.isSelectedCollectionEmpty == expected, "\(context)")
        }
    }
}
