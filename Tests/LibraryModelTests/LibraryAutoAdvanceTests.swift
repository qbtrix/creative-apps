// LibraryAutoAdvanceTests.swift: the live Auto Advance rule (CU-2, #426).
// `LiveCulling.advance` picks the photo to focus after a change: the next
// one, itself when it was last, the photo that took its place when a filter
// hid it, and nil when nothing is shown. The catalog half (CU-3): `cull`
// moves the loupe on after a rating or a flag with Auto Advance on, never on
// a label, in the grid or on undo.
import Testing
@testable import LibraryModel

private let order = ["IMG_0001", "IMG_0002", "IMG_0003", "IMG_0004"]

@Test func liveCullingIsAvailable() {
    #expect(LiveCulling.unavailable == nil)
}

@Test func liveAdvanceGoesToTheNextPhoto() {
    let live = LiveCulling()
    #expect(live.advance(from: "IMG_0001", before: order, after: order) == "IMG_0002")
    #expect(live.advance(from: "IMG_0003", before: order, after: order) == "IMG_0004")
}

@Test func liveAdvanceStaysOnTheLastPhoto() {
    #expect(LiveCulling().advance(from: "IMG_0004", before: order, after: order) == "IMG_0004")
}

@Test func liveAdvanceSkipsPhotosTheChangeHid() {
    // IMG_0001 still shown, IMG_0002 now hidden: the next shown one is IMG_0003.
    let after = ["IMG_0001", "IMG_0003", "IMG_0004"]
    #expect(LiveCulling().advance(from: "IMG_0001", before: order, after: after) == "IMG_0003")
    // Every later photo hidden: the photo was effectively last, so it stays.
    #expect(LiveCulling().advance(from: "IMG_0003", before: order, after: ["IMG_0001", "IMG_0003"]) == "IMG_0003")
}

@Test func liveAdvanceGoesToThePhotoThatTookAHiddenPhotosPlace() {
    let live = LiveCulling()
    // A rating hid IMG_0002: IMG_0003 takes its place.
    #expect(live.advance(from: "IMG_0002", before: order, after: ["IMG_0001", "IMG_0003", "IMG_0004"]) == "IMG_0003")
    // The next one is hidden too: the first later photo still shown.
    #expect(live.advance(from: "IMG_0002", before: order, after: ["IMG_0001", "IMG_0004"]) == "IMG_0004")
}

@Test func liveAdvanceFallsBackToThePreviousShownPhotoWhenTheHiddenOneWasLast() {
    let live = LiveCulling()
    #expect(live.advance(from: "IMG_0004", before: order, after: ["IMG_0001", "IMG_0002", "IMG_0003"]) == "IMG_0003")
    // The one before is hidden as well: the last earlier photo still shown.
    #expect(live.advance(from: "IMG_0004", before: order, after: ["IMG_0001", "IMG_0002"]) == "IMG_0002")
    // Not the first earlier photo: the nearest one.
    #expect(live.advance(from: "IMG_0003", before: order, after: ["IMG_0001", "IMG_0002"]) == "IMG_0002")
}

@Test func liveAdvanceOfAnUnknownIdGoesToTheFirstShownPhoto() {
    let after = ["IMG_0003", "IMG_0004"]
    #expect(LiveCulling().advance(from: "IMG_9999", before: order, after: after) == "IMG_0003")
    #expect(LiveCulling().advance(from: "IMG_0001", before: [], after: after) == "IMG_0003")
}

@Test func liveAdvanceWithNothingShownIsNil() {
    let live = LiveCulling()
    #expect(live.advance(from: "IMG_0001", before: order, after: []) == nil)
    #expect(live.advance(from: "IMG_9999", before: order, after: []) == nil)
    #expect(live.advance(from: "IMG_0001", before: [], after: []) == nil)
}

@Test func liveAdvanceMatchesTheFakeWhenNothingIsFiltered() {
    let live = LiveCulling()
    let fake = FakeCulling()
    for orders in [order, ["IMG_0001"], ["B", "A", "C"]] {
        for id in orders + ["missing"] {
            #expect(live.advance(from: id, before: orders, after: orders)
                    == fake.advance(from: id, before: orders, after: orders))
        }
    }
}

@Test func liveApplyKeepsThePlainRules() throws {
    let photos = LibraryFixtures.photos(named: "samples")
    let first = try #require(photos.first)
    let live = LiveCulling()
    let rated = try live.apply(.rating(5), to: [first.id], in: photos)
    #expect(rated.first?.rating == 5)
    #expect(Array(rated.dropFirst()) == Array(photos.dropFirst()))
    #expect(try live.apply(.flag(.pick), to: [first.id], in: photos).first?.flag == .pick)
    #expect(try live.apply(.label(.red), to: [first.id], in: photos).first?.label == .red)
    #expect(try live.apply(.rating(3), to: [], in: photos) == photos)
}

@Test func liveApplyRefusesARatingOutsideZeroToFive() {
    let photos = LibraryFixtures.photos(named: "samples")
    let ids = Set(photos.prefix(1).map(\.id))
    for stars in [-1, 6] {
        #expect(throws: LibraryError.invalid("A rating is 0 to 5 stars.")) {
            try LiveCulling().apply(.rating(stars), to: ids, in: photos)
        }
    }
}

// MARK: - The catalog's Auto Advance (CU-3)

/// The shoot fixture's photo `IMG_<n>` (ids are paths).
private func shot(_ n: Int) -> String { "/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }

/// The shoot sorted by name, in the loupe on IMG_0001, on `culling`.
private func shootInLoupe(culling: any PhotoCulling = FakeCulling()) -> LibraryCatalog {
    var services = LibraryServices.fake()
    services.culling = culling
    var catalog = LibraryCatalog(services: services)
    catalog.load(LibraryFixtures.photos(named: "shoot"))
    catalog.setSort(.name)
    catalog.open(shot(1))
    return catalog
}

private func rating(_ catalog: LibraryCatalog, _ id: String) -> Int? {
    catalog.items.first { $0.id == id }?.rating
}

@Test func aRatingInTheLoupeAdvancesToTheNextPhoto() {
    for culling: any PhotoCulling in [FakeCulling(), LiveCulling()] {
        var catalog = shootInLoupe(culling: culling)
        catalog.cull(.rating(3))
        #expect(rating(catalog, shot(1)) == 3)
        #expect(catalog.mode == .loupe)
        #expect(catalog.focusedItemID == shot(2))
        catalog.cull(.flag(.pick))
        #expect(catalog.items.first { $0.id == shot(2) }?.flag == .pick)
        #expect(catalog.focusedItemID == shot(3))
    }
}

@Test func aLabelDoesNotAdvance() {
    var catalog = shootInLoupe()
    catalog.cull(.label(.red))
    #expect(catalog.items.first { $0.id == shot(1) }?.label == .red)
    #expect(catalog.focusedItemID == shot(1))
    #expect(catalog.mode == .loupe)
}

@Test func autoAdvanceOffMovesNothing() {
    var catalog = shootInLoupe()
    catalog.setAutoAdvance(false)
    #expect(!catalog.autoAdvance)
    catalog.cull(.rating(3))
    catalog.cull(.flag(.reject))
    #expect(rating(catalog, shot(1)) == 3)
    #expect(catalog.focusedItemID == shot(1))
    catalog.setAutoAdvance(true)
    catalog.cull(.rating(4))
    #expect(catalog.focusedItemID == shot(2))
}

@Test func aCullWithoutAdvanceDoesNotMove() {
    var catalog = shootInLoupe()
    catalog.cull(.rating(3), advance: false)
    catalog.cull(.flag(.pick), advance: false)
    #expect(rating(catalog, shot(1)) == 3)
    #expect(catalog.focusedItemID == shot(1))
}

@Test func theLastPhotoStaysPutWhenItAdvances() {
    var catalog = shootInLoupe()
    catalog.open(shot(24))
    catalog.cull(.rating(2))
    #expect(catalog.focusedItemID == shot(24))
    #expect(catalog.mode == .loupe)
}

@Test func inTheGridTheSelectionNeverMoves() {
    var catalog = shootInLoupe()
    catalog.showGrid()
    catalog.select([shot(1), shot(5)])
    let focus = catalog.focusedItemID
    for change: CullChange in [.rating(3), .flag(.pick), .label(.blue)] {
        catalog.cull(change)
        #expect(catalog.selection == [shot(1), shot(5)])
        #expect(catalog.mode == .grid)
        #expect(catalog.focusedItemID == focus)
    }
}

@Test func undoAfterAnAdvanceRestoresTheRatingAndLeavesTheLoupe() {
    var catalog = shootInLoupe()
    catalog.cull(.rating(3))
    #expect(catalog.focusedItemID == shot(2))
    catalog.undo()
    #expect(rating(catalog, shot(1)) == 0)
    #expect(catalog.mode == .loupe)
    #expect(catalog.focusedItemID == shot(2))
    catalog.redo()
    #expect(rating(catalog, shot(1)) == 3)
    #expect(catalog.focusedItemID == shot(2))
}

@Test func unflaggingInFavoritesGoesToThePhotoThatTookItsPlace() {
    var catalog = shootInLoupe(culling: LiveCulling())
    catalog.showGrid()
    catalog.select([shot(1), shot(2)])
    catalog.cull(.flag(.pick))
    catalog.selectCollection("favorites")
    catalog.open(shot(1))
    catalog.cull(.flag(.none))
    #expect(catalog.order == [shot(2)])
    #expect(catalog.mode == .loupe)
    #expect(catalog.focusedItemID == shot(2))
}

@Test func aChangeThatEmptiesTheShownOrderReturnsToTheGrid() {
    for culling: any PhotoCulling in [FakeCulling(), LiveCulling()] {
        var catalog = shootInLoupe(culling: culling)
        catalog.cull(.flag(.pick), advance: false)
        catalog.selectCollection("favorites")
        catalog.open(shot(1))
        #expect(catalog.mode == .loupe)
        catalog.cull(.flag(.none))
        #expect(catalog.order.isEmpty)
        #expect(catalog.mode == .grid)
        #expect(catalog.focusedItemID == nil)
        #expect(catalog.loupeItem == nil)
    }
}
