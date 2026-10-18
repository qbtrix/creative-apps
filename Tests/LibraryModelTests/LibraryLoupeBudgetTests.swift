// LibraryLoupeBudgetTests.swift: the loupe's model budgets (loupe-viewport
// LV-6, packet Quality tests QB-LIB-5 model half) on the `large` fixture
// (10,000 photos) with `order` cached: one `stepLoupe` within 1 ms debug
// (0.1 ms release), and one `loupeFocusChanged` (LV-2's picture state: the
// held thumbnail as a preview under a new token) within 1 ms debug. Stepping
// never rebuilds `order` (the same buffer before and after). Each prints a
// `LIBRARY-BUDGET loupe …` line. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

#if DEBUG
/// Release limits are a tenth of the debug ones (packet Quality tests).
private let scale = 1.0
#else
private let scale = 0.1
#endif

/// The 10,000-photo catalog with its middle photo open in the loupe.
private func largeLoupe() throws -> (catalog: LibraryCatalog, start: String) {
    var catalog = LibraryCatalog()
    catalog.load(LibraryFixtures.photos(named: "large"))
    let start = try #require(catalog.order.dropFirst(5_000).first)
    catalog.open(start)
    return (catalog, start)
}

/// True when `order` is still the very array `earlier` holds: never rebuilt.
private func sameBuffer(_ order: [String], _ earlier: [String]) -> Bool {
    order.withUnsafeBufferPointer { now in earlier.withUnsafeBufferPointer { now.baseAddress == $0.baseAddress } }
}

@Test func stepWithinBudget() throws {
    var (catalog, start) = try largeLoupe()
    #expect(catalog.order.count == 10_000)
    let order = catalog.order
    var forward = false
    let cost = Budget.measure("loupe step-in-10000") {
        forward.toggle()
        catalog.stepLoupe(by: forward ? 1 : -1)
    }
    // 20 runs alternate +1 and -1, so the loupe ends where it started.
    #expect(catalog.focusedItemID == start)
    catalog.stepLoupe(by: 1)
    #expect(catalog.focusedItemID == catalog.order.dropFirst(5_001).first)
    #expect(catalog.mode == .loupe)
    #expect(sameBuffer(catalog.order, order))
    #expect(cost.median <= 1 * scale)
}

@Test func focusChangeWithinBudget() throws {
    var (catalog, start) = try largeLoupe()
    let thumbnail = try #require(DisplayImage(size: PixelSize(width: 2, height: 2), rgba8: Array(repeating: 9, count: 16)))
    catalog.thumbnails[start] = thumbnail
    let before = catalog.loupeRenderToken
    let cost = Budget.measure("loupe focus-change-in-10000") { catalog.loupeFocusChanged() }
    #expect(catalog.loupeRenderToken == before + 20)
    #expect(catalog.loupeRender == RenderedPhoto(image: thumbnail, histogram: .empty, quality: .preview))
    #expect(catalog.loupeError == nil)
    #expect(cost.median <= 1 * scale)
}
