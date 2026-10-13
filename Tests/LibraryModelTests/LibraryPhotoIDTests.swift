// LibraryPhotoIDTests.swift: photos with the same file name keep distinct ids
// (issue #155). Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import LibraryModel
import Testing

private let date = Date(timeIntervalSince1970: 0)

private func photo(_ name: String, id: String? = nil, minute: Double = 0, flagged: Bool = false) -> PhotoItem {
    PhotoItem(
        id: id, name: name, captureDate: date.addingTimeInterval(minute * 60), color: Color3(0, 0, 0),
        isFlagged: flagged)
}

@Test func idDefaultsToTheNameAndCanBeGiven() {
    #expect(photo("IMG_0001").id == "IMG_0001")
    #expect(photo("IMG_0001", id: "card-a/IMG_0001").id == "card-a/IMG_0001")
}

@Test func photosWithTheSameNameGetDistinctIDs() {
    var catalog = LibraryCatalog()
    catalog.load([photo("IMG_0001"), photo("IMG_0001", minute: 1), photo("IMG_0001", minute: 2)])
    let ids = catalog.sortedItems.map(\.id)
    #expect(ids == ["IMG_0001", "IMG_0001#2", "IMG_0001#3"])
    #expect(catalog.sortedItems.map(\.name) == ["IMG_0001", "IMG_0001", "IMG_0001"])
    #expect(catalog.collections.first?.count == 3)
}

@Test func aRenamedIDNeverTakesAnotherPhotosID() {
    var catalog = LibraryCatalog()
    catalog.load([photo("A"), photo("B", id: "A#2"), photo("A"), photo("A#2"), photo("A")])
    let ids = catalog.items.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(ids.prefix(2) == ["A", "A#2"])
}

@Test func selectionAndLoupeTellSameNamedPhotosApart() {
    var catalog = LibraryCatalog()
    catalog.load([photo("IMG_0001"), photo("IMG_0001", minute: 1)])
    catalog.select(["IMG_0001#2"])
    #expect(catalog.selection == ["IMG_0001#2"])
    catalog.open("IMG_0001#2")
    #expect(catalog.focusedItemID == "IMG_0001#2")
}

@Test func sameNamedPhotosSortInOneOrderWhateverTheInputOrder() {
    let photos = [photo("X", id: "b"), photo("X", id: "a"), photo("X", id: "c")]
    for sort in LibrarySort.allCases {
        var forward = LibraryCatalog()
        var backward = LibraryCatalog()
        forward.setSort(sort)
        backward.setSort(sort)
        forward.load(photos)
        backward.load(photos.reversed())
        #expect(forward.sortedItems.map(\.id) == ["a", "b", "c"])
        #expect(backward.sortedItems.map(\.id) == ["a", "b", "c"])
    }
}

@Test func favoritesCountEachSameNamedPick() {
    var catalog = LibraryCatalog()
    catalog.load([photo("IMG_0001", flagged: true), photo("IMG_0001", minute: 1, flagged: true)])
    catalog.selectCollection("favorites")
    #expect(Set(catalog.sortedItems.map(\.id)).count == 2)
    #expect(catalog.selectedCollection?.count == 2)
}

@Test func sampleIDsStayUniqueAndMatchTheirNames() {
    let items = LibrarySample.items()
    #expect(Set(items.map(\.id)).count == items.count)
    #expect(items.allSatisfy { $0.id == $0.name })
}
