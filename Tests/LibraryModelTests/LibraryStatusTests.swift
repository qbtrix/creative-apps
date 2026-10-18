// LibraryStatusTests.swift: what the Library status bar shows. In the loupe
// it shows the zoom and the photo's own size, on live data too; in the grid
// it shows the photo count, and only on preview data. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

/// The shoot sorted by name, on live (not preview) services.
private func liveShoot() -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.services.isPreview = false
    catalog.load(LibraryFixtures.photos(named: "shoot"))
    catalog.setSort(.name)
    return catalog
}

@Test func theLoupeShowsTheStatusBarWithThePhotosSize() throws {
    var catalog = liveShoot()
    #expect(!catalog.showsStatusBar)
    #expect(catalog.statusSizeText == "24 photos")
    let third = try #require(catalog.sortedItems.dropFirst(2).first)
    catalog.open(third.id)
    #expect(catalog.showsStatusBar)
    #expect(catalog.statusSizeText == "4000 × 6000 px")
    catalog.showGrid()
    #expect(!catalog.showsStatusBar)
    #expect(catalog.statusSizeText == "24 photos")
}

@Test func previewDataShowsTheStatusBarInTheGrid() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    #expect(catalog.showsStatusBar)
}
