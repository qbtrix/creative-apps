// LibraryThumbnailTests.swift: thumbnails TH-1 (packet acceptance row and
// QB-LIB-8, model half): the bucket for a cell, visible-only requests that
// never repeat, no request for a missing file, deterministic tokens, and
// eviction that keeps every visible image and the held bytes under 128 MB.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

/// The 10,000-photo catalog.
private func largeCatalog() -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.load(LibraryFixtures.photos(named: "large"))
    return catalog
}

/// A square image `side` px on a side (1 MB at 512, 4 MB at 1024).
private func squareImage(_ side: Int) -> DisplayImage? {
    DisplayImage(size: PixelSize(width: side, height: side), rgba8: [UInt8](repeating: 128, count: side * side * 4))
}

private func heldBytes(_ catalog: LibraryCatalog) -> Int {
    catalog.thumbnails.values.reduce(0) { $0 + $1.rgba8.count }
}

@Test func cellBucketsCoverTheCellAtScale() {
    var catalog = LibraryCatalog()
    #expect(catalog.thumbnailLongSide(forCell: 160, scale: 2) == 512)
    #expect(catalog.thumbnailLongSide == 512)
    #expect(catalog.thumbnailLongSide(forCell: 280, scale: 2) == 1024)
    #expect(catalog.thumbnailLongSide == 1024)
    #expect(catalog.thumbnailLongSide(forCell: 160, scale: 1) == 256)
    #expect(catalog.thumbnailLongSide == 256)
}

@Test func visibleRequestsNeverRepeat() {
    var catalog = largeCatalog()
    let visible = Array(catalog.order.prefix(30))
    let first = catalog.requestThumbnails(visible: visible)
    #expect(first.count == 30)
    #expect(Set(first.map(\.id)) == Set(visible))
    #expect(first.allSatisfy { $0.longSide == 512 })
    #expect(catalog.requestThumbnails(visible: visible).isEmpty)
    // Held, not pending: still no repeat.
    guard let image = squareImage(512) else { Issue.record("no image"); return }
    for request in first { catalog.setThumbnail(image, for: request) }
    #expect(catalog.pendingThumbnails.isEmpty)
    #expect(catalog.requestThumbnails(visible: visible).isEmpty)
}

@Test func missingPhotoGetsNoRequest() {
    var catalog = LibraryCatalog()
    let date = Date(timeIntervalSince1970: 1_780_308_000)
    catalog.load([
        PhotoItem(name: "A", captureDate: date, color: Color3(0.5, 0.5, 0.5)),
        PhotoItem(name: "B", captureDate: date, color: Color3(0.5, 0.5, 0.5), availability: .missing),
        PhotoItem(name: "C", captureDate: date, color: Color3(0.5, 0.5, 0.5), availability: .unreadable("bad")),
    ])
    let requests = catalog.requestThumbnails(visible: ["A", "B", "C", "nope"])
    #expect(requests.map(\.id) == ["A"])
    #expect(catalog.pendingThumbnails.keys.sorted() == ["A"])
}

@Test func tokenIsDeterministicAndSeesEveryChange() {
    let neutral = DevelopSettings.neutral
    let brighter = neutral.setting(.exposure, to: 0.5)
    let cropped = neutral.setting(crop: CropSettings(angle: 2, rect: .full, aspect: .free))
    #expect(ThumbnailToken.of(neutral, longSide: 512) == ThumbnailToken.of(.neutral, longSide: 512))
    #expect(ThumbnailToken.of(neutral, longSide: 512) != ThumbnailToken.of(neutral, longSide: 1024))
    #expect(ThumbnailToken.of(neutral, longSide: 512) != ThumbnailToken.of(brighter, longSide: 512))
    #expect(ThumbnailToken.of(neutral, longSide: 512) != ThumbnailToken.of(cropped, longSide: 512))
    #expect(ThumbnailToken.of(neutral.setting(.tint, to: 1), longSide: 512)
        != ThumbnailToken.of(neutral.setting(.contrast, to: 1), longSide: 512))
    var catalog = largeCatalog()
    let id = catalog.order.first ?? ""
    let request = catalog.requestThumbnails(visible: [id]).first
    #expect(request?.token == ThumbnailToken.of(.neutral, longSide: 512))
}

/// Scrolls every screen of `large` at `cell` points: requests, answers, then
/// the next visible change; records the first screen over the cap or missing a visible image.
private func scrollEveryScreen(_ catalog: inout LibraryCatalog, cell: Int, perScreen: Int) {
    let side = catalog.thumbnailLongSide(forCell: cell, scale: 2)
    guard let image = squareImage(side) else { Issue.record("no image"); return }
    let order = catalog.order
    var start = 0
    while start < order.count {
        let visible = Array(order[start..<min(start + perScreen, order.count)])
        for request in catalog.requestThumbnails(visible: visible) { catalog.setThumbnail(image, for: request) }
        #expect(catalog.requestThumbnails(visible: visible).isEmpty)
        let bytes = heldBytes(catalog)
        let allHeld = visible.allSatisfy { catalog.thumbnails[$0]?.size.longSide == side }
        if bytes > LibraryCatalog.heldThumbnailBytes || !allHeld {
            Issue.record("screen at \(start): \(bytes) bytes held, every visible held: \(allHeld)")
            return
        }
        start += perScreen
    }
}

@Test func heldBytesStayUnderCap() {
    var catalog = largeCatalog()
    #expect(LibraryCatalog.heldThumbnailBytes == 128 * 1024 * 1024)
    scrollEveryScreen(&catalog, cell: 160, perScreen: 60)
    scrollEveryScreen(&catalog, cell: 280, perScreen: 30)
    #expect(heldBytes(catalog) <= LibraryCatalog.heldThumbnailBytes)
}

@Test func evictionKeepsTwoScreensAroundVisible() {
    var catalog = largeCatalog()
    guard let image = squareImage(64) else { Issue.record("no image"); return }
    let order = catalog.order
    let all = Array(order.prefix(200))
    for request in catalog.requestThumbnails(visible: all) { catalog.setThumbnail(image, for: request) }
    // Visible 100..<110: keep 80..<130, evict the rest.
    _ = catalog.requestThumbnails(visible: Array(order[100..<110]))
    #expect(Set(catalog.thumbnails.keys) == Set(order[80..<130]))
}

@Test func emptyVisibleEvictsNothing() {
    var catalog = largeCatalog()
    guard let image = squareImage(512) else { Issue.record("no image"); return }
    let order = catalog.order
    for request in catalog.requestThumbnails(visible: Array(order.prefix(200))) {
        catalog.setThumbnail(image, for: request)
    }
    // 200 MB held, over the cap and beyond any screen: the loupe keeps it all.
    let held = catalog.thumbnails
    #expect(held.count == 200)
    #expect(catalog.requestThumbnails(visible: []).isEmpty)
    #expect(catalog.thumbnails == held)
}
