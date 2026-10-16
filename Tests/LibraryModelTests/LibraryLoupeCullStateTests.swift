// LibraryLoupeCullStateTests.swift: the loupe shows the cull state of the
// photo it culls (#1661). The inspector's metadata follows the cull targets,
// so in the loupe it names the focused photo, with or without a grid
// selection, and moves with Auto Advance; the loupe's glass readout ends with
// the photo's cull summary. Runs on Linux and macOS.
import LibraryModel
import Testing

@Test func theInspectorShowsTheLoupePhotoWithNothingSelected() throws {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    let order = catalog.sortedItems
    try #require(order.count >= 2)
    catalog.select([])
    catalog.open(order[0].id)
    #expect(catalog.selectedMetadata?.title == order[0].name)
    catalog.cull(.rating(3))
    #expect(catalog.focusedItemID == order[1].id)
    #expect(catalog.selectedMetadata?.title == order[1].name)
}

@Test func theInspectorShowsTheLoupePhotoNotTheGridSelection() throws {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    let order = catalog.sortedItems
    try #require(order.count >= 3)
    catalog.select([order[1].id, order[2].id])
    #expect(catalog.selectedMetadata?.title == "2 Photos")
    catalog.open(order[0].id)
    catalog.setRating(4)
    #expect(catalog.selectedMetadata?.title == order[0].name)
    #expect(catalog.selectedMetadata?.rating == .value(4))
}

@Test func theLoupeReadoutEndsWithTheCullSummary() throws {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.setAutoAdvance(false)
    let first = try #require(catalog.sortedItems.first)
    #expect(catalog.loupeReadout == nil)
    catalog.open(first.id)
    catalog.cull(.rating(3))
    catalog.cull(.flag(.pick))
    catalog.cull(.label(.red))
    let position = try #require(catalog.loupePosition)
    #expect(catalog.loupeReadout == "\(first.name)  ·  \(position)  ·  3 stars, Picked, Red label")
}
