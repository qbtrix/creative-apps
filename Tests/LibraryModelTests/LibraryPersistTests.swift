// LibraryPersistTests.swift: the catalog's side of persistence (PE-1):
// restoring at launch, a failed restore, save requests and revisions, and
// photos whose files are gone. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

private func photo(_ id: String, day: Double) -> PhotoItem {
    PhotoItem(
        id: "/p/\(id).jpg", name: id, captureDate: Date(timeIntervalSince1970: day * 86_400),
        color: Color3(0.5, 0.5, 0.5), path: "/p/\(id).jpg")
}

private let three = [photo("a", day: 1), photo("b", day: 2), photo("c", day: 3)]

@Test func restoreReplacesThePhotosAndIsSaved() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.select([catalog.order[0]])
    catalog.setRating(4)
    catalog.beginRestore()
    #expect(catalog.catalogState == .loading)
    #expect(catalog.saveRequest() == nil)
    catalog.restore(three)
    #expect(catalog.items.map(\.id) == three.map(\.id))
    #expect(catalog.catalogState == .ready)
    #expect(catalog.catalogValue == "saved")
    #expect(catalog.saveRequest() == nil)
    #expect(catalog.selection.isEmpty && catalog.mode == .grid)
    #expect(catalog.collections.first { $0.id == "all" }?.count == 3)
    #expect(catalog.order == three.map(\.id))
    #expect(catalog.undoTitle == nil)  // no step points at the old photos
}

@Test func restoreKeepsTheFirstOfADuplicateID() {
    var catalog = LibraryCatalog()
    catalog.beginRestore()
    let twin = PhotoItem(
        id: three[0].id, name: "twin", captureDate: Date(timeIntervalSince1970: 0), color: Color3(0, 0, 0))
    catalog.restore(three + [twin])
    #expect(catalog.items.map(\.id) == three.map(\.id))
    #expect(catalog.items.first?.name == "a")
}

@Test func restoreWithNoFileKeepsTheFixturePhotos() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    let before = catalog.items
    catalog.beginRestore()
    catalog.restore(nil)
    #expect(catalog.items == before)
    #expect(catalog.catalogState == .ready)
}

@Test func aChangeMakesASaveRequestUntilItsRevisionIsSaved() throws {
    var catalog = LibraryCatalog()
    catalog.beginRestore()
    catalog.restore(three)
    catalog.select([three[0].id])
    catalog.setRating(3)
    #expect(catalog.catalogValue == "dirty")
    let request = try #require(catalog.saveRequest())
    #expect(request.revision == catalog.saveRevision)
    #expect(request.photos.first { $0.id == three[0].id }?.rating == 3)
    catalog.setRating(5)  // a newer change while the first save runs
    catalog.didSave(revision: request.revision)
    #expect(catalog.catalogValue == "dirty")
    let next = try #require(catalog.saveRequest())
    #expect(next.revision > request.revision)
    catalog.didSave(revision: next.revision)
    catalog.didSave(revision: request.revision)  // a late older answer never moves it back
    #expect(catalog.catalogValue == "saved")
    #expect(catalog.saveRequest() == nil)
}

@Test func aFailedSaveKeepsTheReasonAndStaysDirty() throws {
    var catalog = LibraryCatalog()
    catalog.restore(three)
    catalog.select([three[1].id])
    catalog.setRating(2)
    let request = try #require(catalog.saveRequest())
    catalog.failSave(.writeFailed(path: "/c/catalog.json", reason: "The disk is full."))
    #expect(catalog.saveError == "The disk is full.")
    #expect(catalog.catalogValue == "dirty")
    #expect(catalog.saveRequest()?.revision == request.revision)  // the next change retries
    catalog.didSave(revision: request.revision)
    #expect(catalog.saveError == nil)
}

@Test func aNewerCatalogIsNeverSavedOver() {
    var catalog = LibraryCatalog()
    catalog.beginRestore()
    catalog.failRestore(.newerCatalog(version: 2))
    #expect(catalog.catalogState == .newer(version: 2))
    catalog.load(three)
    catalog.select([three[0].id])
    catalog.setRating(1)
    #expect(catalog.catalogValue == "dirty")
    #expect(catalog.saveRequest() == nil)
}

@Test func aDamagedCatalogStartsOverAndSaves() throws {
    var catalog = LibraryCatalog()
    catalog.beginRestore()
    catalog.failRestore(.damagedCatalog(""))
    #expect(catalog.catalogState == .damaged)
    catalog.load(three)
    catalog.select([three[2].id])
    catalog.setRating(4)
    let request = try #require(catalog.saveRequest())
    catalog.didSave(revision: request.revision)
    #expect(catalog.catalogValue == "saved")

    var other = LibraryCatalog()
    other.beginRestore()
    other.failRestore(.invalid("odd"))
    #expect(other.catalogState == .damaged)
}

@Test func aMissingPhotoIsUnreadableButStillRateable() {
    var catalog = LibraryCatalog()
    catalog.beginRestore()
    catalog.restore(three)
    catalog.markMissing([three[1].id, "/not/in/catalog.jpg"])
    #expect(catalog.cellValue(for: three[1].id).hasPrefix("unreadable"))
    #expect(catalog.cellHelp(for: three[1].id) == "The file is missing.")
    #expect(!catalog.cellValue(for: three[0].id).hasPrefix("unreadable"))
    #expect(catalog.catalogValue == "saved")  // nothing to write: the file keeps no availability
    catalog.select([three[1].id])
    catalog.setRating(1)
    #expect(catalog.cellValue(for: three[1].id).contains("1 star"))
}
