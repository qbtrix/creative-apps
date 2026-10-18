// LibraryLoupeZoomTests.swift: the loupe's zoom (loupe-viewport LV-1, #724):
// fit, 100% and the steps between 12.5% and 800%, stepped from the scale the
// loupe draws at now, and the View menu's zoom titles following the browse
// mode. Runs on Linux and macOS.
import LibraryModel
import Testing

/// The samples with the first photo of the sort open in the loupe.
private func loupeCatalog() throws -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    let first = try #require(catalog.sortedItems.first)
    catalog.open(first.id)
    return catalog
}

@Test func eachZoomDrawsAtItsScale() {
    #expect(LoupeZoom.fit.scale(fit: 0.3) == 0.3)
    #expect(LoupeZoom.actual.scale(fit: 0.3) == 1)
    #expect(LoupeZoom.scale(4).scale(fit: 0.3) == 4)
    #expect(LoupeZoom.steps == [0.125, 0.25, 0.5, 1, 2, 4, 8])
}

@Test func aFitThatIsNotAScaleDrawsAtActualSize() {
    #expect(LoupeZoom.fit.scale(fit: 0) == 1)
    #expect(LoupeZoom.fit.scale(fit: .nan) == 1)
    #expect(LoupeZoom.scale(.infinity).scale(fit: 0.3) == 0.3)
}

@Test func zoomingInFromFitWalksTheStepsAndStopsAtTheLast() throws {
    var catalog = try loupeCatalog()
    #expect(catalog.loupeZoom == .fit)
    catalog.stepZoom(by: 1, fitScale: 0.3)
    #expect(catalog.loupeZoom == .scale(0.5))
    catalog.stepZoom(by: 1, fitScale: 0.3)
    #expect(catalog.loupeZoom == .actual)
    catalog.stepZoom(by: 1, fitScale: 0.3)
    #expect(catalog.loupeZoom == .scale(2))
    catalog.stepZoom(by: 1, fitScale: 0.3)
    catalog.stepZoom(by: 1, fitScale: 0.3)
    #expect(catalog.loupeZoom == .scale(8))
    catalog.stepZoom(by: 1, fitScale: 0.3)
    #expect(catalog.loupeZoom == .scale(8))
}

@Test func zoomingOutFromActualGivesHalfAndStopsAtTheFirst() throws {
    var catalog = try loupeCatalog()
    catalog.zoomLoupe(.actual)
    catalog.stepZoom(by: -1, fitScale: 0.3)
    #expect(catalog.loupeZoom == .scale(0.5))
    catalog.stepZoom(by: -1, fitScale: 0.3)
    catalog.stepZoom(by: -1, fitScale: 0.3)
    #expect(catalog.loupeZoom == .scale(0.125))
    catalog.stepZoom(by: -1, fitScale: 0.3)
    #expect(catalog.loupeZoom == .scale(0.125))
}

@Test func aFitOnAStepMovesToTheNextStepNotOntoItself() throws {
    var catalog = try loupeCatalog()
    catalog.stepZoom(by: 1, fitScale: 0.5)
    #expect(catalog.loupeZoom == .actual)
    catalog.zoomLoupe(.fit)
    catalog.stepZoom(by: -1, fitScale: 0.5)
    #expect(catalog.loupeZoom == .scale(0.25))
}

@Test func aMultiStepMovesThatManyStepsAndZeroDoesNothing() throws {
    var catalog = try loupeCatalog()
    catalog.stepZoom(by: 0, fitScale: 0.3)
    #expect(catalog.loupeZoom == .fit)
    catalog.stepZoom(by: 3, fitScale: 0.3)
    #expect(catalog.loupeZoom == .scale(2))
    catalog.stepZoom(by: -Int.max, fitScale: 0.3)
    #expect(catalog.loupeZoom == .scale(0.125))
}

@Test func zoomLoupeKeepsAValidZoomAndIgnoresAnInvalidScale() throws {
    var catalog = try loupeCatalog()
    catalog.zoomLoupe(.scale(3))
    #expect(catalog.loupeZoom == .scale(3))
    catalog.zoomLoupe(.scale(1))
    #expect(catalog.loupeZoom == .actual)
    catalog.zoomLoupe(.scale(0))
    catalog.zoomLoupe(.scale(.nan))
    catalog.zoomLoupe(.scale(-2))
    #expect(catalog.loupeZoom == .actual)
    catalog.zoomLoupe(.fit)
    #expect(catalog.loupeZoom == .fit)
}

@Test func theZoomTitlesFollowTheMode() throws {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    #expect(catalog.mode == .grid)
    #expect(catalog.zoomInTitle == "Larger Thumbnails")
    #expect(catalog.zoomOutTitle == "Smaller Thumbnails")
    catalog = try loupeCatalog()
    #expect(catalog.zoomInTitle == "Zoom In")
    #expect(catalog.zoomOutTitle == "Zoom Out")
}
