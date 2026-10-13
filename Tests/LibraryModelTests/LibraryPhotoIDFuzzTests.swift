// LibraryPhotoIDFuzzTests.swift: adversarial and seeded fuzz tests for the
// unique photo ids LibraryCatalog.load(_:) assigns (#155). Same names, given
// ids that look like renamed ones, canonically equal Unicode names and large
// loads, checked against the catalog's invariants. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import LibraryModel
import Testing

/// xorshift64*: a tiny deterministic generator so a failing load replays.
private struct XorShift: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }
}

private let epoch = Date(timeIntervalSince1970: 0)

private func shot(_ name: String, id: String? = nil, minute: Int = 0, flagged: Bool = false) -> PhotoItem {
    PhotoItem(
        id: id, name: name, captureDate: epoch.addingTimeInterval(Double(minute) * 60), color: Color3(0, 0, 0),
        isFlagged: flagged)
}

/// A random load from a small pool of names and given ids, so clashes are common.
private func randomPhotos(_ rng: inout XorShift) -> [PhotoItem] {
    let names = ["IMG_0001", "IMG_0002", "A", "A#2", "A#2#2", "", "#", "#2"]
    let givenIDs: [String?] = [nil, nil, nil, "A", "A#2", "A#3", "IMG_0001", "IMG_0001#2", "", "#2"]
    return (0..<Int.random(in: 0...40, using: &rng)).map { _ in
        shot(
            names.randomElement(using: &rng) ?? "A", id: givenIDs.randomElement(using: &rng) ?? nil,
            minute: Int.random(in: 0...3, using: &rng), flagged: Bool.random(using: &rng))
    }
}

/// True when the photos match apart from their ids.
private func sameApartFromID(_ a: PhotoItem, _ b: PhotoItem) -> Bool {
    a.name == b.name && a.captureDate == b.captureDate && a.color == b.color && a.rating == b.rating
        && a.isFlagged == b.isFlagged && a.label == b.label
}

private func expectInvariants(_ catalog: LibraryCatalog, loaded photos: [PhotoItem]) {
    let ids = catalog.items.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(catalog.items.count == photos.count)
    #expect(zip(catalog.items, photos).allSatisfy { sameApartFromID($0, $1) })
    // A photo either keeps its id or gets "<its id>#<n>".
    #expect(zip(catalog.items, photos).allSatisfy { $0.id == $1.id || $0.id.hasPrefix($1.id + "#") })
    #expect(catalog.collections.first { $0.id == "all" }?.count == photos.count)
    #expect(catalog.collections.first { $0.id == "favorites" }?.count == photos.filter(\.isFlagged).count)
}

@Test func seededLoadsKeepEveryIDUniqueAndEveryPhoto() {
    var rng = XorShift(state: 0x155)
    for _ in 0..<300 {
        let photos = randomPhotos(&rng)
        var catalog = LibraryCatalog()
        catalog.load(photos)
        expectInvariants(catalog, loaded: photos)
    }
}

@Test func reloadingTheCatalogsOwnItemsKeepsTheirIDs() {
    var rng = XorShift(state: 0xA11)
    for _ in 0..<100 {
        var catalog = LibraryCatalog()
        catalog.load(randomPhotos(&rng))
        let first = catalog.items
        catalog.load(first)
        #expect(catalog.items == first)
    }
}

@Test func everyCollectionAndSortShowsEachPhotoOnceInATotalOrder() {
    var rng = XorShift(state: 0x50F7)
    for _ in 0..<100 {
        var catalog = LibraryCatalog()
        catalog.load(randomPhotos(&rng))
        for collection in ["all", "favorites", "recent"] {
            catalog.selectCollection(collection)
            for sort in LibrarySort.allCases {
                catalog.setSort(sort)
                let ids = catalog.sortedItems.map(\.id)
                #expect(Set(ids).count == ids.count)
                #expect(ids.count == catalog.selectedCollection?.count)
                // Sorting the sorted list again in reverse input order gives the same list.
                var reversed = catalog
                reversed.load(catalog.sortedItems.reversed())
                reversed.selectCollection(collection)
                reversed.setSort(sort)
                #expect(reversed.sortedItems.map(\.id) == ids)
            }
        }
    }
}

@Test func selectingAndOpeningEveryShownPhotoWorks() {
    var rng = XorShift(state: 0x5E1)
    for _ in 0..<50 {
        var catalog = LibraryCatalog()
        catalog.load(randomPhotos(&rng))
        let ids = Set(catalog.sortedItems.map(\.id))
        catalog.select(ids)
        #expect(catalog.selection == ids)
        for id in ids {
            catalog.open(id)
            #expect(catalog.focusedItemID == id)
        }
    }
}

@Test func givenIDsThatLookRenamedNeverCollide() {
    var catalog = LibraryCatalog()
    let photos = [
        shot("A"), shot("A"), shot("X", id: "A#2"), shot("X", id: "A#3"), shot("A"), shot("A#2"), shot("A#2"),
        shot("A#2#2"),
    ]
    catalog.load(photos)
    expectInvariants(catalog, loaded: photos)
    #expect(catalog.items.first?.id == "A")
}

@Test func emptyAndHashOnlyNamesGetDistinctIDs() {
    var catalog = LibraryCatalog()
    let photos = [shot(""), shot(""), shot("#2"), shot("#"), shot("#")]
    catalog.load(photos)
    expectInvariants(catalog, loaded: photos)
}

@Test func canonicallyEqualUnicodeNamesAreOneIDAndGetRenamed() {
    // "Café" precomposed and decomposed are equal Swift strings, so they clash.
    let precomposed = "Caf\u{E9}"
    let decomposed = "Cafe\u{301}"
    var catalog = LibraryCatalog()
    let photos = [shot(precomposed), shot(decomposed, minute: 1)]
    catalog.load(photos)
    expectInvariants(catalog, loaded: photos)
    #expect(catalog.sortedItems.count == 2)
    catalog.select(Set(catalog.sortedItems.map(\.id)))
    #expect(catalog.selection.count == 2)
}

@Test func tenThousandSameNamedPhotosLoadWithDistinctIDs() {
    let photos = (0..<10_000).map { shot("IMG_0001", minute: $0 % 7, flagged: $0 % 3 == 0) }
    var catalog = LibraryCatalog()
    catalog.load(photos)
    expectInvariants(catalog, loaded: photos)
    #expect(catalog.items.last?.id == "IMG_0001#10000")
    catalog.selectCollection("recent")
    #expect(Set(catalog.sortedItems.map(\.id)).count == LibraryCatalog.recentLimit)
}

@Test func recentlyAddedPicksTheSameTiedPhotosWhateverTheInputOrder() {
    // 25 photos share one capture date; Recently Added keeps 20 of them by name then id.
    let photos = (0..<25).map { shot("IMG_" + String(100 + $0), id: "id" + String(100 + $0)) }
    var forward = LibraryCatalog()
    var backward = LibraryCatalog()
    forward.load(photos)
    backward.load(photos.reversed())
    forward.selectCollection("recent")
    backward.selectCollection("recent")
    #expect(forward.sortedItems.map(\.id) == backward.sortedItems.map(\.id))
    #expect(forward.selectedCollection?.count == LibraryCatalog.recentLimit)
}
