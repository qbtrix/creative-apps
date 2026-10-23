// LibraryThumbnailResultTests.swift: thumbnails TH-2 (packet acceptance row):
// a stale result is dropped (develop changed, request no longer pending, token
// mismatch while pending), a failure marks the cell unreadable with its help,
// and invalidation drops the image and request so the next pass asks again.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

/// Two available photos, A and B, with the 512 bucket.
private func twoPhotoCatalog() -> LibraryCatalog {
    var catalog = LibraryCatalog()
    let date = Date(timeIntervalSince1970: 1_780_308_000)
    catalog.load([
        PhotoItem(name: "A", captureDate: date, color: Color3(0.5, 0.5, 0.5)),
        PhotoItem(name: "B", captureDate: date, color: Color3(0.5, 0.5, 0.5)),
    ])
    _ = catalog.thumbnailLongSide(forCell: 160, scale: 2)
    return catalog
}

/// The 4:3 image a 4032 × 3024 photo gets at the 512 bucket.
private func bucketImage() -> DisplayImage? {
    DisplayImage(size: PixelSize(width: 512, height: 384), rgba8: [UInt8](repeating: 128, count: 512 * 384 * 4))
}

private func setExposure(_ catalog: inout LibraryCatalog, _ id: String, _ value: Double) {
    guard let index = catalog.items.firstIndex(where: { $0.id == id }) else { return }
    catalog.items[index].develop = catalog.items[index].develop.setting(.exposure, to: value)
}

@Test func currentResultIsStored() throws {
    var catalog = twoPhotoCatalog()
    let image = try #require(bucketImage())
    let request = try #require(catalog.requestThumbnails(visible: ["A"]).first)
    catalog.setThumbnail(image, for: request)
    #expect(catalog.thumbnails["A"] == image)
    #expect(catalog.pendingThumbnails["A"] == nil)
    #expect(catalog.cellValue(for: "A").hasPrefix("ready 512×384"))
}

@Test func resultAfterDevelopChangeAndInvalidateIsDropped() throws {
    var catalog = twoPhotoCatalog()
    let image = try #require(bucketImage())
    let old = try #require(catalog.requestThumbnails(visible: ["A"]).first)
    setExposure(&catalog, "A", 0.5)
    catalog.invalidateThumbnail("A")
    let fresh = try #require(catalog.requestThumbnails(visible: ["A"]).first)
    #expect(fresh.token != old.token)
    catalog.setThumbnail(image, for: old)
    #expect(catalog.thumbnails["A"] == nil)
    #expect(catalog.pendingThumbnails["A"] == fresh)
    catalog.setThumbnail(image, for: fresh)
    #expect(catalog.thumbnails["A"] == image)
}

@Test func resultForRequestNoLongerPendingIsDropped() throws {
    var catalog = twoPhotoCatalog()
    let image = try #require(bucketImage())
    let request = try #require(catalog.requestThumbnails(visible: ["A"]).first)
    catalog.setThumbnail(image, for: request)
    catalog.invalidateThumbnail("A")
    catalog.setThumbnail(image, for: request)  // a duplicate answer after the image was dropped
    #expect(catalog.thumbnails["A"] == nil)
    // A request never made for B is ignored too.
    let stray = ThumbnailRequest(id: "B", longSide: 512, token: ThumbnailToken.of(.neutral, longSide: 512))
    catalog.setThumbnail(image, for: stray)
    #expect(catalog.thumbnails["B"] == nil)
}

@Test func resultWithStaleTokenIsDroppedWhilePending() throws {
    var catalog = twoPhotoCatalog()
    let image = try #require(bucketImage())
    let request = try #require(catalog.requestThumbnails(visible: ["A"]).first)
    setExposure(&catalog, "A", -1)  // no invalidate: the request is still pending
    #expect(catalog.pendingThumbnails["A"] == request)
    catalog.setThumbnail(image, for: request)
    #expect(catalog.thumbnails["A"] == nil)
    #expect(catalog.cellValue(for: "A").hasPrefix("loading"))
    let again = try #require(catalog.requestThumbnails(visible: ["A"]).first)
    #expect(again.token == ThumbnailToken.of(catalog.items.first?.develop ?? .neutral, longSide: 512))
}

@Test func missingFileMakesCellUnreadable() throws {
    var catalog = twoPhotoCatalog()
    let request = try #require(catalog.requestThumbnails(visible: ["A"]).first)
    #expect(catalog.cellValue(for: "A").hasPrefix("loading"))
    catalog.failThumbnail(request, .missingFile("/photos/A.jpg"))
    #expect(catalog.cellValue(for: "A").hasPrefix("unreadable"))
    #expect(catalog.cellHelp(for: "A") == "The file is missing.")
    #expect(catalog.pendingThumbnails["A"] == nil)
    #expect(catalog.requestThumbnails(visible: ["A"]).isEmpty)
}

@Test func otherFailuresGiveTheirReason() throws {
    var catalog = twoPhotoCatalog()
    let requests = catalog.requestThumbnails(visible: ["A", "B"])
    let a = try #require(requests.first { $0.id == "A" })
    let b = try #require(requests.first { $0.id == "B" })
    catalog.failThumbnail(a, .notAnImage("/photos/A.jpg"))
    #expect(catalog.cellValue(for: "A").hasPrefix("unreadable"))
    #expect(catalog.cellHelp(for: "A") == "Library can't read this file: not an image file.")
    // A cancelled request says nothing about the file: B stays readable and is asked again.
    catalog.failThumbnail(b, .cancelled)
    #expect(catalog.cellHelp(for: "B") == nil)
    #expect(catalog.cellValue(for: "B").hasPrefix("loading"))
    #expect(catalog.requestThumbnails(visible: ["B"]).map(\.id) == ["B"])
}

@Test func staleFailureIsDropped() throws {
    var catalog = twoPhotoCatalog()
    let request = try #require(catalog.requestThumbnails(visible: ["A"]).first)
    catalog.invalidateThumbnail("A")
    catalog.failThumbnail(request, .missingFile("/photos/A.jpg"))
    #expect(catalog.cellHelp(for: "A") == nil)
    #expect(catalog.cellValue(for: "A").hasPrefix("loading"))
}

@Test func invalidateDropsImageAndPendingSoTheNextPassAsksAgain() throws {
    var catalog = twoPhotoCatalog()
    let image = try #require(bucketImage())
    let requests = catalog.requestThumbnails(visible: ["A", "B"])
    let a = try #require(requests.first { $0.id == "A" })
    catalog.setThumbnail(image, for: a)
    #expect(catalog.requestThumbnails(visible: ["A", "B"]).isEmpty)
    catalog.invalidateThumbnail("A")
    catalog.invalidateThumbnail("B")
    #expect(catalog.thumbnails["A"] == nil)
    #expect(catalog.pendingThumbnails.isEmpty)
    #expect(catalog.cellValue(for: "A").hasPrefix("loading"))
    #expect(Set(catalog.requestThumbnails(visible: ["A", "B"]).map(\.id)) == ["A", "B"])
}

@Test func onePassOfResultsLandsTogether() throws {
    var catalog = twoPhotoCatalog()
    let image = try #require(bucketImage())
    let requests = catalog.requestThumbnails(visible: ["A", "B"])
    let a = try #require(requests.first { $0.id == "A" })
    let b = try #require(requests.first { $0.id == "B" })
    catalog.applyThumbnails([(a, .success(image)), (b, .failure(.missingFile("/photos/B.jpg")))])
    #expect(catalog.thumbnails["A"] == image)
    #expect(catalog.cellValue(for: "B").hasPrefix("unreadable"))
    #expect(catalog.pendingThumbnails.isEmpty)
}

@Test func aStaleResultInAPassIsDropped() throws {
    var catalog = twoPhotoCatalog()
    let image = try #require(bucketImage())
    let old = try #require(catalog.requestThumbnails(visible: ["A"]).first)
    catalog.invalidateThumbnail("A")
    catalog.applyThumbnails([(old, .success(image))])
    #expect(catalog.thumbnails["A"] == nil)
}
