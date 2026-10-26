// LibraryThumbnailPrefetchTests.swift: a scroll's thumbnail pass (large-catalog
// LG-5, #3108). The visible cells are asked first, then two screens either
// side of them in `order`, nearest first; a pending request that scrolled
// out of that window comes back cancelled, so its decode stops and a late
// answer is dropped. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

@Suite struct LibraryThumbnailPrefetchTests {
    let catalog: LibraryCatalog = {
        var catalog = LibraryCatalog()
        let date = Date(timeIntervalSince1970: 1_780_308_000)
        let names = (0..<30).map { "p\($0 < 10 ? "0" : "")\($0)" }
        catalog.load(names.map { PhotoItem(name: $0, captureDate: date, color: Color3(0.5, 0.5, 0.5)) })
        return catalog
    }()

    /// A 512-bucket cache.
    func cache() -> LibraryThumbnailCache {
        var cache = LibraryThumbnailCache()
        _ = cache.thumbnailLongSide(forCell: 160, scale: 2)
        return cache
    }

    /// The ids at `indices` of the catalog's display order.
    func shown(_ indices: [Int]) -> [String] { indices.map { catalog.order[$0] } }

    @Test func asksTheVisibleCellsThenTwoScreensEitherSideNearestFirst() {
        var cache = cache()
        let pass = cache.thumbnailPass(visible: shown([10, 11]), in: catalog)
        // Two visible cells: a screen is two, so four either side.
        #expect(pass.requests.map(\.id) == shown([10, 11, 12, 9, 13, 8, 14, 7, 15, 6]))
        #expect(pass.cancelled.isEmpty)
        #expect(Set(cache.pendingThumbnails.keys) == Set(pass.requests.map(\.id)))
    }

    @Test func theWindowStopsAtTheEndsOfTheOrder() {
        var cache = cache()
        let pass = cache.thumbnailPass(visible: shown([0, 1]), in: catalog)
        #expect(pass.requests.map(\.id) == shown([0, 1, 2, 3, 4, 5]))
    }

    @Test func aScrollCancelsThePendingRequestsLeftBehind() {
        var cache = cache()
        let first = cache.thumbnailPass(visible: shown([0, 1]), in: catalog)
        let next = cache.thumbnailPass(visible: shown([20, 21]), in: catalog)
        #expect(next.cancelled == first.requests.sorted { $0.id < $1.id })
        #expect(next.requests.map(\.id) == shown([20, 21, 22, 19, 23, 18, 24, 17, 25, 16]))
        #expect(Set(cache.pendingThumbnails.keys) == Set(next.requests.map(\.id)))
    }

    @Test func aCancelledRequestsLateAnswerIsDropped() throws {
        var cache = cache()
        let image = try #require(DisplayImage(size: PixelSize(width: 512, height: 384), rgba8: [UInt8](repeating: 128, count: 512 * 384 * 4)))
        let first = cache.thumbnailPass(visible: shown([0, 1]), in: catalog)
        let request = try #require(first.requests.first)
        _ = cache.thumbnailPass(visible: shown([20, 21]), in: catalog)
        cache.setThumbnail(image, for: request, in: catalog)
        #expect(cache.thumbnails[request.id] == nil)
    }

    @Test func aSmallScrollKeepsWhatIsStillInTheWindow() {
        var cache = cache()
        _ = cache.thumbnailPass(visible: shown([10, 11]), in: catalog)
        let next = cache.thumbnailPass(visible: shown([12, 13]), in: catalog)
        // The window moves from 6...15 to 8...17: 6 and 7 leave, 16 and 17 join.
        #expect(next.cancelled.map(\.id) == shown([6, 7]).sorted())
        #expect(next.requests.map(\.id) == shown([16, 17]))
    }

    @Test func nothingVisibleAsksAndCancelsNothing() {
        var cache = cache()
        let first = cache.thumbnailPass(visible: shown([10, 11]), in: catalog)
        let pass = cache.thumbnailPass(visible: [], in: catalog)
        #expect(pass == ThumbnailPass(requests: [], cancelled: []))
        #expect(cache.pendingThumbnails.count == first.requests.count)
    }

    @Test func findsAPhotoByIdWithoutAScan() {
        var cache = cache()
        let id = catalog.order[7]
        #expect(cache.photo(id, in: catalog)?.id == id)
        #expect(cache.photo("nope", in: catalog) == nil)
    }
}
