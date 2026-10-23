// LibrarySearchBudgetTests.swift: search's budget (metadata-more MD-21,
// packet Quality tests QB-LIB-M3) on the `large` fixture (10,000 photos)
// given the `cameras` details and Beach on every fifth photo: one
// `setSearch("iso:>800 beach")` within 50 ms debug (5 ms release). It prints a
// `LIBRARY-BUDGET search …` line. Written before its code (rule 13, MD-19): it
// waits on MD-21, whose `setSearch` replaces the stand-in in
// LibrarySearchOrderTests.swift. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

#if DEBUG
/// Release limits are a tenth of the debug ones (packet Quality tests).
private let scale = 1.0
#else
private let scale = 0.1
#endif

/// The `large` photos, each with the camera of `IMG_(i mod 23 + 1)` and every fifth tagged Beach.
private func searchablePhotos() -> [PhotoItem] {
    LibraryFixtures.photos(named: "large").enumerated().map { index, photo in
        PhotoItem(
            id: photo.id, name: photo.name, captureDate: photo.captureDate, color: photo.color,
            path: photo.path, pixelSize: photo.pixelSize,
            keywords: index % 5 == 0 ? ["Beach"] : [], camera: LibraryFixtures.camera(index % 23 + 1))
    }
}

@Test(.disabled("waits on MD-21")) func searchWithinBudget() {
    let photos = searchablePhotos()
    let expected = photos.filter { ($0.camera.iso ?? 0) > 800 && $0.keywords.contains("Beach") }.count
    var catalog = LibraryCatalog()
    catalog.load(photos)
    var round = 0
    let cost = Budget.measure("search iso-and-keyword-in-10000") {
        // A trailing space on every other run, so no run can reuse the last one's text.
        round += 1
        catalog.setSearch(round % 2 == 0 ? "iso:>800 beach" : "iso:>800 beach ")
    }
    #expect(expected > 0)
    #expect(catalog.order.count == expected)
    #expect(cost.median <= 50 * scale)
}
