// LibraryLoupeImageTests.swift: the loupe's picture state in LibraryCatalog
// (loupe-viewport LV-2): the thumbnail preview on a focus change, render
// requests under a token, latest wins, failures that keep the last picture,
// and the neighbours to prefetch. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

private func pixels(_ value: UInt8, side: Int = 2) -> DisplayImage? {
    DisplayImage(size: PixelSize(width: side, height: side), rgba8: Array(repeating: value, count: side * side * 4))
}

private func render(_ value: UInt8, _ quality: RenderQuality) -> RenderedPhoto? {
    pixels(value).map { RenderedPhoto(image: $0, histogram: .empty, quality: quality) }
}

/// Asks for a full render at 2048 px; fails the test outside the loupe.
private func fullRequest(_ catalog: inout LibraryCatalog) throws -> LoupeRequest {
    let request = catalog.loupeRequest(longSide: 2048, quality: .full)
    return try #require(request)
}

/// The samples loaded with the third photo of the sort open in the loupe.
private func loupeOnThird() -> (catalog: LibraryCatalog, order: [String]) {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    let order = catalog.order
    catalog.open(order[2])
    return (catalog, order)
}

@Test func focusChangeShowsTheHeldThumbnailAsAPreview() throws {
    var (catalog, order) = loupeOnThird()
    let thumbnail = try #require(pixels(7))
    catalog.thumbnails[order[2]] = thumbnail
    catalog.loupeZoom = .actual
    catalog.loupeError = "old"
    let before = catalog.loupeRenderToken
    catalog.loupeFocusChanged()
    #expect(catalog.loupeRenderToken == before + 1)
    #expect(catalog.loupeRender == RenderedPhoto(image: thumbnail, histogram: .empty, quality: .preview))
    #expect(catalog.loupeError == nil)
    #expect(catalog.loupeZoom == .actual)
    #expect(catalog.loupeValue?.hasPrefix("preview 2×2") == true)
}

@Test func focusChangeWithNoThumbnailClearsThePicture() throws {
    var (catalog, order) = loupeOnThird()
    catalog.thumbnails[order[2]] = try #require(pixels(7))
    catalog.loupeFocusChanged()
    catalog.stepLoupe(by: 1)
    catalog.loupeFocusChanged()
    #expect(catalog.loupeRender == nil)
    #expect(catalog.loupeValue?.hasPrefix("loading") == true)
}

@Test func requestCarriesThePhotoItsSettingsAndANewToken() throws {
    var (catalog, order) = loupeOnThird()
    let before = catalog.loupeRenderToken
    let request = try fullRequest(&catalog)
    let photo = try #require(catalog.items.first { $0.id == order[2] })
    #expect(request == LoupeRequest(photo: photo, settings: photo.develop, longSide: 2048,
                                    quality: .full, token: before + 1))
    #expect(catalog.loupeRenderToken == before + 1)
}

@Test func noRequestOutsideTheLoupe() {
    var (catalog, _) = loupeOnThird()
    catalog.showGrid()
    let before = catalog.loupeRenderToken
    #expect(catalog.loupeRequest(longSide: 2048, quality: .full) == nil)
    #expect(catalog.loupeRenderToken == before)
}

@Test func aRenderForAnOlderTokenIsDropped() throws {
    var (catalog, _) = loupeOnThird()
    let old = try fullRequest(&catalog)
    let new = try fullRequest(&catalog)
    catalog.showLoupeRender(try #require(render(1, .full)), token: old.token)
    #expect(catalog.loupeRender == nil)
    let latest = try #require(render(2, .full))
    catalog.showLoupeRender(latest, token: new.token)
    #expect(catalog.loupeRender == latest)
    catalog.showLoupeRender(try #require(render(3, .full)), token: old.token)
    #expect(catalog.loupeRender == latest)
}

@Test func aPreviewAfterAFullOfTheSameTokenIsDropped() throws {
    var (catalog, _) = loupeOnThird()
    let request = try fullRequest(&catalog)
    let full = try #require(render(1, .full))
    catalog.showLoupeRender(full, token: request.token)
    catalog.showLoupeRender(try #require(render(2, .preview)), token: request.token)
    #expect(catalog.loupeRender == full)
    let sharper = try #require(render(3, .full))
    catalog.showLoupeRender(sharper, token: request.token)
    #expect(catalog.loupeRender == sharper)
}

@Test func aFullReplacesThePreviewAndClearsTheError() throws {
    var (catalog, order) = loupeOnThird()
    catalog.thumbnails[order[2]] = try #require(pixels(7))
    catalog.loupeFocusChanged()
    let request = try fullRequest(&catalog)
    catalog.loupeError = "old"
    let full = try #require(render(1, .full))
    catalog.showLoupeRender(full, token: request.token)
    #expect(catalog.loupeRender == full)
    #expect(catalog.loupeError == nil)
}

@Test func aFailureKeepsTheLastPictureAndSaysWhy() throws {
    var (catalog, _) = loupeOnThird()
    let first = try fullRequest(&catalog)
    let shown = try #require(render(1, .full))
    catalog.showLoupeRender(shown, token: first.token)
    let next = try fullRequest(&catalog)
    catalog.failLoupeRender(.renderFailed("the file is damaged"), token: next.token)
    #expect(catalog.loupeRender == shown)
    #expect(catalog.loupeError == "Couldn't render this photo: the file is damaged.")
}

@Test func aFailureForAnOldTokenChangesNothing() throws {
    var (catalog, _) = loupeOnThird()
    let old = try fullRequest(&catalog)
    _ = catalog.loupeRequest(longSide: 2048, quality: .full)
    let before = catalog
    catalog.failLoupeRender(.renderFailed("late"), token: old.token)
    #expect(catalog == before)
    #expect(catalog.loupeError == nil)
}

@Test func neighboursAreThePhotosBeforeAndAfterInTheSort() {
    var (catalog, order) = loupeOnThird()
    #expect(catalog.neighboursToPrefetch().map(\.id) == [order[1], order[3]])
    catalog.open(order[0])
    #expect(catalog.neighboursToPrefetch().map(\.id) == [order[1]])
    catalog.open(order[order.count - 1])
    #expect(catalog.neighboursToPrefetch().map(\.id) == [order[order.count - 2]])
    catalog.showGrid()
    #expect(catalog.neighboursToPrefetch().isEmpty)
}

@Test func aLonePhotoHasNoNeighbours() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.order = [catalog.order[0]]
    catalog.open(catalog.order[0])
    #expect(catalog.neighboursToPrefetch().isEmpty)
}
