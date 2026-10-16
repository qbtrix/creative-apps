// LibraryAutoAdvanceTests.swift: the live Auto Advance rule (CU-2, #426).
// `LiveCulling.advance` picks the photo to focus after a change: the next
// one, itself when it was last, the photo that took its place when a filter
// hid it, and nil when nothing is shown.
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
