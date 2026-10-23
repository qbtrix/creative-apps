// LibraryGridBudgetTests.swift: the grid model's budgets (thumbnails TH-4,
// packet Quality tests QB-LIB-3, model half) on the `large` fixture (10,000
// photos): `requestThumbnails` for 60 visible cells within 5 ms debug
// (0.5 ms release), both on a fresh catalog and while scrolling with the held
// images over the 128 MB cap, so every pass also evicts. Each run asks for a
// screen it has not asked for, so every timed pass makes 60 requests. Each
// prints a `LIBRARY-BUDGET grid …` line. Runs on Linux and macOS.
import CoreColor
@testable import LibraryModel
import Testing

#if DEBUG
/// Release limits are a tenth of the debug ones (packet Quality tests).
private let scale = 1.0
#else
private let scale = 0.1
#endif

/// The 10,000-photo catalog, built fresh so each copy owns its storage.
private func largeCatalog() -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.load(LibraryFixtures.photos(named: "large"))
    return catalog
}

/// A square image `side` px on a side (1 MB at 512, 2 MB at 724).
private func squareImage(_ side: Int) -> DisplayImage? {
    DisplayImage(size: PixelSize(width: side, height: side), rgba8: [UInt8](repeating: 128, count: side * side * 4))
}

private func heldBytes(_ catalog: LibraryCatalog) -> Int {
    catalog.thumbnails.values.reduce(0) { $0 + $1.rgba8.count }
}

/// The `screen`-th run of 60 ids in `order`.
private func screen(_ order: [String], _ screen: Int) -> [String] {
    let start = min(screen * 60, max(order.count - 60, 0))
    return Array(order[start..<min(start + 60, order.count)])
}

@Suite struct LibraryGridBudgetTests {
    @Test func requestThumbnailsWithinBudget() {
        var catalog = largeCatalog()
        #expect(catalog.thumbnailLongSide(forCell: 160, scale: 2) == 512)
        let order = catalog.order
        var next = 0
        var counts: [Int] = []
        let cost = Budget.measure("grid request-60-of-10000") {
            counts.append(catalog.requestThumbnails(visible: screen(order, next)).count)
            next += 1
        }
        #expect(counts.count == 20)
        #expect(counts.allSatisfy { $0 == 60 })
        #expect(catalog.pendingThumbnails.count == 20 * 60)
        #expect(cost.median <= 5 * scale)
    }

    @Test func scrollWithEvictionWithinBudget() {
        var catalog = largeCatalog()
        _ = catalog.thumbnailLongSide(forCell: 160, scale: 2)
        // 2 MB answers, so the two screens kept behind the visible one
        // (240 MB) pass the cap and the farthest-first pass runs every time.
        guard let image = squareImage(724) else { Issue.record("no image"); return }
        let order = catalog.order
        for index in 0..<3 {
            for request in catalog.requestThumbnails(visible: screen(order, index)) {
                catalog.setThumbnail(image, for: request)
            }
        }
        #expect(heldBytes(catalog) > LibraryCatalog.heldThumbnailBytes)
        var next = 3
        var counts: [Int] = []
        var worst = 0
        var allVisibleHeld = true
        let cost = Budget.measure("grid scroll-60-with-eviction") {
            let visible = screen(order, next)
            let requests = catalog.requestThumbnails(visible: visible)
            counts.append(requests.count)
            worst = max(worst, heldBytes(catalog))
            for request in requests { catalog.setThumbnail(image, for: request) }
            allVisibleHeld = allVisibleHeld && visible.allSatisfy { catalog.thumbnails[$0] != nil }
            next += 1
        }
        #expect(counts.count == 20)
        #expect(counts.allSatisfy { $0 == 60 })
        #expect(allVisibleHeld)
        #expect(worst <= LibraryCatalog.heldThumbnailBytes)
        #expect(cost.median <= 5 * scale)
    }
}
