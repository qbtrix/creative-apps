// LibraryExcludedPathsCodingTests.swift: the catalog file keeps the paths
// Delete Rejects trashed (cull-finish DR-7). A catalog with excluded paths
// round-trips; with none the file is byte-equal to the golden, so every old
// catalog stays as it was; `photo.delete-rejects` is a command with its
// availability. Runs on Linux and macOS.
import Foundation
@testable import LibraryModel
import SuiteKernel
import Testing

private let coding = LiveCatalogCoding()

/// The shoot with IMG_0002, IMG_0005 and IMG_0008 rejected, on a FakeTrash.
private func shootWithRejects() -> LibraryCatalog {
    var photos = LibraryFixtures.shoot()
    for index in [1, 4, 7] { photos[index].flag = .reject }
    var catalog = LibraryCatalog(services: .fake(photos))
    catalog.load(photos)
    return catalog
}

@Test func excludedPathsSurviveSave() throws {
    var catalog = shootWithRejects()
    catalog.deleteRejects()
    let data = try coding.encode(catalog.items, excludedPaths: catalog.excludedPaths)
    let file = try coding.decodeFile(data)
    #expect(file.excludedPaths == catalog.excludedPaths)
    #expect(file.excludedPaths.count == 3)
    #expect(file.photos == catalog.items)
    #expect(try coding.decode(data) == catalog.items)
    #expect(try coding.encode(file.photos, excludedPaths: file.excludedPaths) == data)
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains(#""excludedPaths" : ["#))
    let order = ["IMG_0002", "IMG_0005", "IMG_0008"].compactMap { text.range(of: $0 + ".jpg\"")?.lowerBound }
    #expect(order.count == 3 && order == order.sorted(), "written sorted, so equal sets give equal bytes")
}

@Test func goldensUnchanged() throws {
    let data = try coding.encode(LibraryPersistGolden.photos, excludedPaths: [])
    #expect(String(decoding: data, as: UTF8.self) == LibraryPersistGolden.catalogV1)
    #expect(try coding.encode(LibraryPersistGolden.photos) == data)
    #expect(!String(decoding: data, as: UTF8.self).contains("excludedPaths"))
    let file = try coding.decodeFile(Data(LibraryPersistGolden.catalogV1.utf8))
    #expect(file.excludedPaths.isEmpty)
    #expect(file.photos == LibraryPersistGolden.photos)
}

@Test func aDamagedExcludedListIsADamagedCatalog() {
    let bad = LibraryPersistGolden.catalogV1.replacingOccurrences(of: #""photos""#, with: #""excludedPaths" : 3, "photos""#)
    #expect(throws: LibraryError.damagedCatalog("")) { try coding.decodeFile(Data(bad.utf8)) }
}

@Test func deleteRejectsIsACommandWithItsAvailability() throws {
    let catalog = LibraryCatalog.catalog
    #expect(catalog.ids.contains("photo.delete-rejects"))
    var none = LibraryCatalog(services: .fake())
    none.load(LibraryFixtures.shoot())
    #expect(catalog.availability("photo.delete-rejects", on: none).why == none.deleteRejectsHelp)
    #expect(none.deleteRejectsHelp != nil)
    #expect(throws: CatalogError.self) { try catalog.run("photo.delete-rejects", params: .object([:]), on: &none) }

    var rejects = shootWithRejects()
    #expect(catalog.availability("photo.delete-rejects", on: rejects).why == nil)
    let ran = try catalog.run("photo.delete-rejects", params: .object([:]), on: &rejects)
    #expect(ran.undoStep == "Delete Rejects")
    #expect(ran.result == .object(["moved": .number(3), "failed": .number(0)]))
    #expect(rejects.items.count == 21)
}
