// LibraryThumbnailPositionTests.swift: thumbnails TH-4. The id → index cache
// behind requestThumbnails and eviction stays right after a sort, a
// collection change, an import and a removal, so a pass that only looks at
// the visible and held ids still answers as a full scan would.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

/// `count` photos p0, p1, ...: capture date ascending, name descending, so the
/// name sort reverses the capture-date order. Every third one is flagged.
private func photos(_ count: Int, from start: Int = 0) -> [PhotoItem] {
    (start..<start + count).map { index in
        let name = "N" + String(9_000 - index)  // four digits for every index used here
        return PhotoItem(
            id: "p\(index)", name: name, captureDate: Date(timeIntervalSince1970: 1_780_000_000 + Double(index)),
            color: Color3(0.5, 0.5, 0.5), isFlagged: index % 3 == 0)
    }
}

private func image() -> DisplayImage? {
    DisplayImage(size: PixelSize(width: 4, height: 3), rgba8: [UInt8](repeating: 128, count: 48))
}

/// Every id in `order` and `items` resolves to its first index; an unknown id to nil.
private func expectPositions(_ catalog: inout LibraryCatalog) {
    for (index, id) in catalog.order.enumerated() {
        var rebuilt = false
        #expect(catalog.orderIndex(of: id, rebuilt: &rebuilt) == index)
    }
    for (index, item) in catalog.items.enumerated() {
        var rebuilt = false
        #expect(catalog.itemIndex(of: item.id, rebuilt: &rebuilt) == index)
    }
    var rebuilt = false
    #expect(catalog.orderIndex(of: "nope", rebuilt: &rebuilt) == nil)
    #expect(catalog.itemIndex(of: "nope", rebuilt: &rebuilt) == nil)
}

/// Requests `visible` and answers every request with `image`.
private func show(_ visible: [String], in catalog: inout LibraryCatalog, image: DisplayImage) {
    for request in catalog.requestThumbnails(visible: visible) { catalog.setThumbnail(image, for: request) }
}

@Test func sortMovesHeldImagesOutOfTheKeptSpan() {
    guard let image = image() else { Issue.record("no image"); return }
    var catalog = LibraryCatalog()
    catalog.load(photos(100))
    show(Array(catalog.order.prefix(10)), in: &catalog, image: image)
    #expect(catalog.thumbnails.count == 10)
    expectPositions(&catalog)
    catalog.setSort(.name)  // p0...p9 move to the end, 81+ cells from the new top screen
    expectPositions(&catalog)
    let top = Array(catalog.order.prefix(10))
    #expect(top.first == "p99")
    show(top, in: &catalog, image: image)
    #expect(Set(catalog.thumbnails.keys) == Set(top))
}

@Test func collectionChangeDropsHiddenImages() {
    guard let image = image() else { Issue.record("no image"); return }
    var catalog = LibraryCatalog()
    catalog.load(photos(30))
    show(Array(catalog.order.prefix(6)), in: &catalog, image: image)
    catalog.selectCollection("favorites")
    expectPositions(&catalog)
    #expect(catalog.order.first == "p0")
    show(["p0"], in: &catalog, image: image)
    #expect(Set(catalog.thumbnails.keys) == ["p0", "p3"])  // p1, p2, p4, p5 are hidden now
}

@Test func importedPhotosGetRequestsAndResults() {
    guard let image = image() else { Issue.record("no image"); return }
    var catalog = LibraryCatalog()
    catalog.load(photos(20))
    show(Array(catalog.order.prefix(5)), in: &catalog, image: image)
    catalog.appendImported(photos(5, from: 20))
    expectPositions(&catalog)
    let requests = catalog.requestThumbnails(visible: ["p20", "p24"])
    #expect(requests.map(\.id) == ["p20", "p24"])
    if let first = requests.first { catalog.setThumbnail(image, for: first) }
    #expect(catalog.thumbnails["p20"] != nil)
    if let last = requests.last { catalog.failThumbnail(last, .missingFile("gone")) }
    #expect(catalog.items.last?.availability == .missing)
}

@Test func removedPhotosLoseTheirImages() {
    guard let image = image() else { Issue.record("no image"); return }
    var catalog = LibraryCatalog()
    catalog.load(photos(20))
    show(Array(catalog.order.prefix(5)), in: &catalog, image: image)
    catalog.load(photos(20, from: 100))  // same count, other ids: every cached slot now holds another id
    expectPositions(&catalog)
    let top = Array(catalog.order.prefix(5))
    show(top, in: &catalog, image: image)
    #expect(Set(catalog.thumbnails.keys) == Set(top))
}
