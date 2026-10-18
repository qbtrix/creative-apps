// LibraryLoadingEmptyStateTests.swift: the content shows no empty state
// while the launch read runs (persist, PE-8), so a saved catalog never
// flashes "No Photos" before it appears. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

private let saved = [
    PhotoItem(
        id: "/p/a.jpg", name: "a", captureDate: Date(timeIntervalSince1970: 86_400),
        color: Color3(0.5, 0.5, 0.5), path: "/p/a.jpg")
]

@Test func anEmptyCatalogShowsNoEmptyStateWhileLoading() {
    var catalog = LibraryCatalog()
    #expect(catalog.isEmpty)
    #expect(catalog.showsEmptyState)
    catalog.beginRestore()
    #expect(catalog.isEmpty)
    #expect(!catalog.showsEmptyState)
}

@Test func aRestoreWithPhotosShowsThemNotAnEmptyState() {
    var catalog = LibraryCatalog()
    catalog.beginRestore()
    catalog.restore(saved)
    #expect(!catalog.isEmpty)
    #expect(!catalog.showsEmptyState)
}

@Test func aRestoreWithNoFileShowsNoPhotos() {
    var catalog = LibraryCatalog()
    catalog.beginRestore()
    catalog.restore(nil)
    #expect(catalog.showsEmptyState)
    #expect(catalog.emptyState(importReason: nil).title == "No Photos")
}

@Test func aDamagedOrNewerCatalogStillShowsItsState() {
    var catalog = LibraryCatalog()
    catalog.beginRestore()
    catalog.failRestore(.damagedCatalog("bad json"))
    #expect(catalog.showsEmptyState)
    #expect(catalog.emptyState(importReason: nil).title == "New Catalog Started")
    catalog.beginRestore()
    catalog.failRestore(.newerCatalog(version: 2))
    #expect(catalog.showsEmptyState)
    #expect(catalog.emptyState(importReason: nil).title == "Catalog Not Opened")
}
