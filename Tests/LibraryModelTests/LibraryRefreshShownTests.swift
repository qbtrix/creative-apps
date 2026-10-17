// LibraryRefreshShownTests.swift: refreshShown keeps the order, the selection
// and the loupe true to what the selected collection shows, and UserCollection
// tells its own ids and its smart rules apart (filters-collections FC-2).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import Testing
@testable import LibraryModel

/// Four unrated photos P1...P4 a day apart, in the grid, none selected.
private func fourPhotos() -> LibraryCatalog {
    var catalog = LibraryCatalog(services: .fake())
    catalog.load((1...4).map {
        PhotoItem(
            name: "P\($0)", captureDate: Date(timeIntervalSince1970: 1_767_225_600 + Double($0) * 86_400),
            color: Color3(0, 0, 0))
    })
    return catalog
}

@Test func refreshShownRebuildsTheOrderFromTheShownPhotos() {
    var catalog = fourPhotos()
    catalog.order = []
    catalog.refreshShown()
    #expect(catalog.order == catalog.shownItems.sorted { catalog.sort.orders($0, before: $1) }.map(\.id))
    #expect(catalog.order.count == 4)
}

@Test func refreshShownDropsSelectedPhotosThatAreNotShown() {
    var catalog = fourPhotos()
    catalog.selection = ["P1", "ghost"]
    catalog.refreshShown()
    #expect(catalog.selection == ["P1"])
}

@Test func refreshShownLeavesTheLoupeOnAShownPhoto() {
    var catalog = fourPhotos()
    catalog.mode = .loupe
    catalog.focusedItemID = "P2"
    catalog.refreshShown()
    #expect(catalog.mode == .loupe)
    #expect(catalog.focusedItemID == "P2")
}

@Test func refreshShownReturnsTheLoupeToTheGridWhenItsPhotoIsHidden() {
    var catalog = fourPhotos()
    catalog.mode = .loupe
    catalog.focusedItemID = "ghost"
    catalog.refreshShown()
    #expect(catalog.mode == .grid)
    #expect(catalog.focusedItemID == nil)
}

@Test func userCollectionIDsAreUserOrSmartOnly() {
    #expect(UserCollection.isUserID("user-1"))
    #expect(UserCollection.isUserID("smart-2"))
    #expect(!UserCollection.isUserID("all"))
    #expect(!UserCollection.isUserID("favorites"))
}

@Test func userCollectionIsSmartOnlyWhenItsContentsAreRules() {
    let photos = UserCollection(id: "user-1", name: "Keepers", contents: .photos(["P1"]))
    let smart = UserCollection(id: "smart-1", name: "Five stars", contents: .rules(LibraryFilter()))
    #expect(!photos.isSmart)
    #expect(smart.isSmart)
}
