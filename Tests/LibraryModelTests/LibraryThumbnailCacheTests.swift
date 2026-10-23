// LibraryThumbnailCacheTests.swift: #2709. LibraryThumbnailCache works apart from
// the catalog it reads; a pass without failures leaves the catalog as it was.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

@Suite struct LibraryThumbnailCacheTests {
    let catalog: LibraryCatalog = {
        var catalog = LibraryCatalog()
        let date = Date(timeIntervalSince1970: 1_780_308_000)
        catalog.load(["A", "B", "C"].map { PhotoItem(name: $0, captureDate: date, color: Color3(0.5, 0.5, 0.5)) })
        return catalog
    }()

    /// A 512-bucket cache.
    func cache() -> LibraryThumbnailCache {
        var cache = LibraryThumbnailCache()
        _ = cache.thumbnailLongSide(forCell: 160, scale: 2)
        return cache
    }

    func image() throws -> DisplayImage {
        try #require(DisplayImage(size: PixelSize(width: 512, height: 384), rgba8: [UInt8](repeating: 128, count: 512 * 384 * 4)))
    }

    @Test func requestsVisiblePhotosOnceWithoutTouchingTheCatalog() {
        var cache = cache()
        let requests = cache.requestThumbnails(visible: ["A", "B", "A", "nope"], in: catalog)
        #expect(requests.map(\.id) == ["A", "B"])
        #expect(requests.allSatisfy { $0.longSide == 512 })
        #expect(cache.pendingThumbnails.keys.sorted() == ["A", "B"])
        #expect(cache.requestThumbnails(visible: ["A", "B"], in: catalog).isEmpty)
        #expect(catalog.pendingThumbnails.isEmpty && catalog.thumbnails.isEmpty)
    }

    @Test func applyStoresCurrentDropsStaleAndReturnsFailures() throws {
        var cache = cache()
        let image = try image()
        let requests = cache.requestThumbnails(visible: ["A", "B", "C"], in: catalog)
        #expect(requests.count == 3)
        let stale = ThumbnailRequest(id: "A", longSide: 512, token: 7)
        var results: [(request: ThumbnailRequest, result: Result<DisplayImage, LibraryError>)] = [
            (stale, .success(image)),
        ]
        for request in requests {
            switch request.id {
            case "A": results.append((request, .success(image)))
            case "B": results.append((request, .failure(.missingFile("/b.jpg"))))
            default: results.append((request, .failure(.cancelled)))
            }
        }
        let failures = cache.applyThumbnails(results, in: catalog)
        #expect(failures == ["B": .missing])
        #expect(cache.thumbnails.keys.sorted() == ["A"])
        #expect(cache.pendingThumbnails.isEmpty)
    }

    @Test func unreadableFailureCarriesItsReason() throws {
        var cache = cache()
        let request = try #require(cache.requestThumbnails(visible: ["C"], in: catalog).first)
        let failures = cache.applyThumbnails([(request, .failure(.renderFailed("bad bytes")))], in: catalog)
        #expect(failures == ["C": .unreadable(LibraryError.renderFailed("bad bytes").message)])
        // A failure for a request no longer pending is dropped.
        #expect(cache.applyThumbnails([(request, .failure(.missingFile("/c.jpg")))], in: catalog).isEmpty)
    }

    @Test func applyThumbnailFailuresMarksOnlyTheFailedPhotos() {
        var catalog = catalog
        catalog.applyThumbnailFailures(["B": .missing, "C": .unreadable("bad"), "nope": .missing])
        #expect(catalog.items.map(\.availability) == [.available, .missing, .unreadable("bad")])
        #expect(catalog.cellValue(for: "B").hasPrefix("unreadable"))
    }

    @Test func passWithoutFailuresLeavesTheCatalogAsItWas() throws {
        var cache = cache()
        let image = try image()
        let before = catalog
        let requests = cache.requestThumbnails(visible: ["A", "B"], in: catalog)
        var after = catalog
        after.applyThumbnailFailures(cache.applyThumbnails(requests.map { ($0, .success(image)) }, in: catalog))
        #expect(after == before)
        #expect(cache.thumbnails.count == 2)
        #expect(LibraryCatalog.cellValue(photo: catalog.items[0], thumbnail: cache.thumbnails["A"]).hasPrefix("ready 512×384"))
    }

    @Test func catalogForwardsMatchTheCache() throws {
        var catalog = catalog
        let image = try image()
        _ = catalog.thumbnailLongSide(forCell: 160, scale: 2)
        let request = try #require(catalog.requestThumbnails(visible: ["B"]).first)
        catalog.failThumbnail(request, .missingFile("/b.jpg"))
        #expect(catalog.items.map(\.availability) == [.available, .missing, .available])
        let next = try #require(catalog.requestThumbnails(visible: ["A"]).first)
        catalog.applyThumbnails([(next, .success(image))])
        #expect(catalog.thumbnailCache.thumbnails["A"] == image)
        catalog.open("A")
        catalog.loupeFocusChanged(from: LibraryThumbnailCache())
        #expect(catalog.loupeRender == nil)
        catalog.loupeFocusChanged()
        #expect(catalog.loupeRender?.image == image)
    }
}
