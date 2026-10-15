// LibraryCatalogTests.swift: behavior of LibraryCatalog, the state behind
// Library's window. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

@Test func startsEmptyOnAllPhotos() {
    let catalog = LibraryCatalog()
    #expect(catalog.isEmpty)
    #expect(catalog.collections.map(\.name) == ["All Photos", "Favorites", "Recently Added"])
    #expect(catalog.selectedCollection?.id == "all")
}

@Test func selectsKnownCollectionsOnly() {
    var catalog = LibraryCatalog()
    catalog.selectCollection("favorites")
    #expect(catalog.selectedCollectionID == "favorites")
    catalog.selectCollection("trash")
    #expect(catalog.selectedCollectionID == "favorites")
}

@Test func anEmptyCollectionIsEmptyWhileTheCatalogIsNot() {
    var catalog = LibraryCatalog()
    #expect(catalog.isSelectedCollectionEmpty)
    catalog.load(LibrarySample.items().filter { !$0.isFlagged })
    #expect(!catalog.isEmpty && !catalog.isSelectedCollectionEmpty)
    catalog.selectCollection("favorites")
    #expect(!catalog.isEmpty && catalog.isSelectedCollectionEmpty && catalog.sortedItems.isEmpty)
    catalog.selectCollection("recent")
    #expect(!catalog.isSelectedCollectionEmpty)
    catalog.loadSamples()
    catalog.selectCollection("favorites")
    #expect(!catalog.isSelectedCollectionEmpty)
}

@Test func aNewCatalogStartsOnFakeServicesReadyWithAutoAdvance() {
    let catalog = LibraryCatalog()
    #expect(catalog.services.isPreview)
    #expect(catalog.autoAdvance)
    #expect(catalog.catalogState == .ready)
    #expect(catalog.importState == .idle && catalog.exportState == .idle && catalog.loupeZoom == .fit)
    #expect(catalog.order.isEmpty && catalog.saveRevision == catalog.savedRevision)
}

@Test func catalogsThatDifferOnlyInServicesAreEqual() {
    #expect(LibraryCatalog(services: .fake()) == LibraryCatalog(services: .fake(mode: .fail)))
}

/// One change per stored property other than `services`.
private func storedPropertyChanges() -> [(String, (inout LibraryCatalog) -> Void)] {
    let image = DisplayImage(size: PixelSize(width: 1, height: 1), rgba8: [0, 0, 0, 255])
    let crop = CropSettings(angle: 0, rect: .full, aspect: .free)
    return [
        ("collections", { $0.collections[0].count = 9 }),
        ("selectedCollectionID", { $0.selectedCollectionID = "recent" }),
        ("items", { $0.items = LibrarySample.items() }),
        ("sort", { $0.sort = .rating }),
        ("cellSize", { $0.cellSize = 200 }),
        ("selection", { $0.selection = ["a"] }),
        ("mode", { $0.mode = .loupe }),
        ("focusedItemID", { $0.focusedItemID = "a" }),
        ("history", { $0.history.push(.init(name: "Set Rating", before: [], after: [])) }),
        ("order", { $0.order = ["a"] }),
        ("importState", { $0.importState = .running(ImportProgress(done: 0, total: 1)) }),
        ("importNotice", { $0.importNotice = ImportNotice(folder: "Shoot") }),
        ("thumbnails", { $0.thumbnails = image.map { ["a": $0] } ?? [:] }),
        ("thumbnailLongSide", { $0.thumbnailLongSide = 1024 }),
        ("pendingThumbnails", { $0.pendingThumbnails = ["a": ThumbnailRequest(id: "a", longSide: 512, token: 0)] }),
        ("autoAdvance", { $0.autoAdvance = false }),
        ("loupeZoom", { $0.loupeZoom = .scale(2) }),
        ("loupeRender", { $0.loupeRender = image.map { RenderedPhoto(image: $0, histogram: .empty, quality: .full) } }),
        ("loupeRenderToken", { $0.loupeRenderToken = 1 }),
        ("loupeError", { $0.loupeError = "No" }),
        ("copiedSettings", { $0.copiedSettings = .neutral }),
        ("cropDraft", { $0.cropDraft = crop }),
        ("exportState", { $0.exportState = .running(done: 0, total: 1) }),
        ("catalogState", { $0.catalogState = .damaged }),
        ("saveRevision", { $0.saveRevision = 1 }),
        ("savedRevision", { $0.savedRevision = 1 }),
        ("saveError", { $0.saveError = "No" }),
        ("showsTestValues", { $0.showsTestValues = true }),
        ("cullError", { $0.cullError = "No" }),
    ]
}

@Test func catalogsThatDifferInAnyOtherStoredPropertyAreNotEqual() {
    let changes = storedPropertyChanges()
    #expect(changes.count == 29)
    for (name, change) in changes {
        var changed = LibraryCatalog()
        change(&changed)
        #expect(changed != LibraryCatalog(), "\(name) is left out of ==")
    }
}
