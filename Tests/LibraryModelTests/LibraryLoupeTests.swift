// LibraryLoupeTests.swift: entering, stepping through and leaving the loupe in
// LibraryCatalog (#29). Runs on Linux and macOS.
import LibraryModel
import Testing

/// The samples loaded with the 12th photo of the sort open in the loupe.
private func loupeOnTwelfth() -> (catalog: LibraryCatalog, order: [String]) {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    let order = catalog.sortedItems.map(\.id)
    catalog.open(order[11])
    return (catalog, order)
}

@Test func openingShowsThatPhotoAndItsPosition() {
    let (catalog, order) = loupeOnTwelfth()
    #expect(catalog.mode == .loupe)
    #expect(catalog.loupeItem?.id == order[11])
    #expect(catalog.loupePosition == "12 of 60")
}

@Test func nextOnTheLastPhotoStaysPut() {
    var (catalog, order) = loupeOnTwelfth()
    catalog.open(order[59])
    #expect(!catalog.canShowNextInLoupe && catalog.canShowPreviousInLoupe)
    catalog.stepLoupe(by: 1)
    #expect(catalog.loupeItem?.id == order[59])
    #expect(catalog.loupePosition == "60 of 60")
}

@Test func previousOnTheFirstPhotoStaysPut() {
    var (catalog, order) = loupeOnTwelfth()
    catalog.open(order[0])
    #expect(!catalog.canShowPreviousInLoupe && catalog.canShowNextInLoupe)
    catalog.stepLoupe(by: -1)
    #expect(catalog.loupeItem?.id == order[0])
    #expect(catalog.loupePosition == "1 of 60")
}

@Test func steppingFollowsTheSortAndClampsHugeSteps() {
    var (catalog, order) = loupeOnTwelfth()
    catalog.stepLoupe(by: 1)
    #expect(catalog.loupeItem?.id == order[12])
    catalog.stepLoupe(by: -2)
    #expect(catalog.loupeItem?.id == order[10])
    catalog.stepLoupe(by: Int.max)
    #expect(catalog.loupeItem?.id == order[59])
    catalog.stepLoupe(by: Int.min)
    #expect(catalog.loupeItem?.id == order[0])
}

@Test func returningToTheGridKeepsThePhotoSelected() {
    var (catalog, order) = loupeOnTwelfth()
    catalog.stepLoupe(by: 1)
    catalog.showGrid()
    #expect(catalog.mode == .grid)
    #expect(catalog.selection == [order[12]])
    #expect(catalog.loupeItem == nil && catalog.loupePosition == nil)
}

@Test func viewLoupeOpensTheSelectedPhotoOrTheFirst() {
    var catalog = LibraryCatalog()
    catalog.showLoupe()
    #expect(catalog.mode == .grid)
    catalog.loadSamples()
    let order = catalog.sortedItems.map(\.id)
    catalog.showLoupe()
    #expect(catalog.loupeItem?.id == order[0])
    catalog.showGrid()
    catalog.select([order[30], order[20]])
    catalog.showLoupe()
    #expect(catalog.loupeItem?.id == order[20])
}


/// The 24-photo shoot fixture sorted by name, IMG_0003 open in the loupe.
private func shootOnThird() -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.load(LibraryFixtures.photos(named: "shoot"))
    catalog.setSort(.name)
    catalog.open(catalog.sortedItems.map(\.id)[2])
    return catalog
}

@Test func endShowsTheLastPhotoAndHomeTheFirst() {
    var catalog = shootOnThird()
    let order = catalog.sortedItems.map(\.id)
    catalog.showLastInLoupe()
    #expect(catalog.loupeItem?.id == order[23] && catalog.loupePosition == "24 of 24")
    catalog.showFirstInLoupe()
    #expect(catalog.loupeItem?.id == order[0] && catalog.loupePosition == "1 of 24")
}

@Test func homeAndEndDoNothingInTheGrid() {
    var catalog = shootOnThird()
    catalog.showGrid()
    let selection = catalog.selection
    catalog.showLastInLoupe()
    catalog.showFirstInLoupe()
    #expect(catalog.mode == .grid && catalog.loupeItem == nil && catalog.selection == selection)
}

@Test func theReadoutNamesThePhotoThenItsPosition() {
    let catalog = shootOnThird()
    #expect(catalog.loupeItem?.name == "IMG_0003")
    #expect(catalog.loupeReadout?.hasPrefix("IMG_0003  ·  3 of 24  ·  ") == true)
}

@Test func theLoupeDrawsThePhotoAtItsOwnSize() {
    var catalog = shootOnThird()
    #expect(catalog.loupeItem?.name == "IMG_0003")
    let portrait = catalog.loupePhotoSize
    #expect(portrait == PixelSize(width: 4000, height: 6000))
    #expect((portrait?.height ?? 0) > (portrait?.width ?? 0), "a portrait photo draws taller than wide")
    #expect(catalog.loupePlaceholder == "IMG_0003  ·  4000 × 6000")
    catalog.stepLoupe(by: 1)
    #expect(catalog.loupePhotoSize == PixelSize(width: 6000, height: 4000))
    catalog.showGrid()
    #expect(catalog.loupePhotoSize == nil && catalog.loupePlaceholder == nil)
}

@Test func aPhotoWithoutPixelsStillHasASize() {
    let shoot = LibraryFixtures.photos(named: "shoot")
    var catalog = LibraryCatalog()
    catalog.load(shoot.prefix(1).map {
        PhotoItem(name: $0.name, captureDate: $0.captureDate, color: $0.color, pixelSize: PixelSize(width: 0, height: -3))
    })
    catalog.showLoupe()
    #expect(catalog.loupePhotoSize == PixelSize(width: 1, height: 1))
}

@Test func theLoupeHelpSaysWhyThePhotoCantShow() {
    var catalog = shootOnThird()
    #expect(catalog.loupeHelp == nil)
    catalog.failLoupeRender(.renderFailed("no memory"), token: catalog.loupeRenderToken)
    #expect(catalog.loupeHelp == "Couldn't render this photo: no memory.")
    catalog.showGrid()
    #expect(catalog.loupeHelp == nil)

    let shoot = LibraryFixtures.photos(named: "shoot")
    var missing = LibraryCatalog()
    missing.load(shoot.prefix(1).map {
        PhotoItem(name: $0.name, captureDate: $0.captureDate, color: $0.color, availability: .missing)
    })
    missing.showLoupe()
    missing.failLoupeRender(.renderFailed("no file"), token: missing.loupeRenderToken)
    #expect(missing.loupeHelp == "The file is missing.", "the file's own reason comes first")
}
