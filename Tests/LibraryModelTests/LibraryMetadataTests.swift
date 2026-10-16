// LibraryMetadataTests.swift: the inspector's metadata edits on LibraryCatalog:
// rating, flag and label on every selected photo, mixed values, the named
// undo steps they share with the cull keys, the loupe photo as their target
// in the loupe, and a budget for one edit across all 60 samples. Runs on
// Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import LibraryModel
import Testing

/// Three photos rated 1, 2 and 3 stars, all selected.
private func threeSelected() -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.load((1...3).map {
        PhotoItem(
            name: "P\($0)", captureDate: Date(timeIntervalSince1970: 1_767_225_600), color: Color3(0, 0, 0), rating: $0)
    })
    catalog.select(["P1", "P2", "P3"])
    return catalog
}

@Test func aRatingOutside0To5IsRefused() {
    var catalog = threeSelected()
    catalog.setRating(6)
    catalog.setRating(-1)
    #expect(catalog.items.map(\.rating) == [1, 2, 3])
    catalog.setRating(5)
    #expect(catalog.items.map(\.rating) == [5, 5, 5])
}

@Test func anEditAppliesToEverySelectedPhotoOnly() {
    var catalog = threeSelected()
    catalog.select(["P1", "P3"])
    catalog.setFlag(.reject)
    catalog.setLabel(.green)
    #expect(catalog.items.map(\.flag) == [.reject, .none, .reject])
    #expect(catalog.items.map(\.label) == [.green, nil, .green])
}

@Test func clickingTheCurrentRatingsStarClearsIt() {
    var catalog = threeSelected()
    catalog.clickStar(4)
    #expect(catalog.selectedMetadata?.rating == .value(4))
    catalog.clickStar(4)
    #expect(catalog.items.map(\.rating) == [0, 0, 0])
}

@Test func differingValuesAreMixed() throws {
    var catalog = threeSelected()
    let mixed = try #require(catalog.selectedMetadata)
    #expect(mixed.title == "3 Photos")
    #expect(mixed.rating == .mixed && mixed.flag == .value(.none) && mixed.label == .value(nil))
    catalog.select(["P2"])
    #expect(catalog.selectedMetadata?.title == "P2")
    #expect(catalog.selectedMetadata?.rating == .value(2))
    catalog.select([])
    #expect(catalog.selectedMetadata == nil)
}

@Test func unflaggingInFavoritesUpdatesTheCountAndSelection() {
    var catalog = threeSelected()
    catalog.setFlag(.pick)
    #expect(catalog.collections.first { $0.id == "favorites" }?.count == 3)
    catalog.selectCollection("favorites")
    catalog.select(["P1"])
    catalog.setFlag(.none)
    #expect(catalog.collections.first { $0.id == "favorites" }?.count == 2)
    #expect(catalog.selection.isEmpty)
}

/// QB-L7's shape for Library: one rating edit on all 60 samples plus the
/// inspector's summary stays under 10 ms in debug (1 ms on a device), p95 of 50.
@Test func oneEditOnSixtyPhotosStaysInBudget() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.select(Set(catalog.items.map(\.id)))
    let clock = ContinuousClock()
    let times = (0..<50).map { run in
        clock.measure {
            catalog.setRating(run % 6)
            _ = catalog.selectedMetadata
        }
    }.sorted()
    #expect(times.count == 50 && times[47] < .milliseconds(10))
}

@Test func aStarClickIsOneSetRatingStepThatUndoes() {
    var catalog = threeSelected()
    let before = catalog.items
    catalog.clickStar(4)
    #expect(catalog.items.map(\.rating) == [4, 4, 4])
    #expect(catalog.undoTitle == "Undo Set Rating")
    #expect(catalog.history.undo.count == 1)
    catalog.undo()
    #expect(catalog.items == before)
}

@Test func flagAndLabelEditsAreNamedLikeTheKeys() {
    var catalog = threeSelected()
    catalog.setFlag(.reject)
    #expect(catalog.undoTitle == "Undo Reject")
    catalog.setFlag(.pick)
    #expect(catalog.undoTitle == "Undo Pick")
    catalog.setFlag(.none)
    #expect(catalog.undoTitle == "Undo Clear Flag")
    catalog.setLabel(.red)
    #expect(catalog.undoTitle == "Undo Set Label")
    #expect(catalog.history.undo.map(\.name) == ["Reject", "Pick", "Clear Flag", "Set Label"])
}

@Test func anOutOfRangeRatingLeavesNoErrorOrStep() {
    var catalog = threeSelected()
    catalog.setRating(6)
    catalog.setRating(-1)
    #expect(catalog.cullError == nil && catalog.history.undo.isEmpty)
}

@Test func inTheLoupeAStarClickRatesTheLoupePhotoAndStays() {
    var catalog = threeSelected()
    catalog.open("P2")
    catalog.setAutoAdvance(true)
    catalog.clickStar(4)
    #expect(catalog.items.map(\.rating) == [1, 4, 3])
    #expect(catalog.mode == .loupe && catalog.loupeItem?.id == "P2")
    #expect(catalog.undoTitle == "Undo Set Rating")
    catalog.clickStar(4)
    #expect(catalog.items.map(\.rating) == [1, 0, 3])
    #expect(catalog.loupeItem?.id == "P2")
}

@Test func inTheLoupeTheStarClearsByTheLoupePhotosRating() {
    var catalog = threeSelected()
    catalog.select(["P1", "P3"])
    catalog.open("P2")
    catalog.clickStar(2)
    #expect(catalog.items.map(\.rating) == [1, 0, 3])
}

@Test func aRefusedFlagLeavesThePhotosAndSaysWhy() {
    var catalog = LibraryCatalog(services: .fake(mode: .fail))
    catalog.load(threeSelected().items)
    catalog.select(["P1", "P2"])
    let before = catalog.items
    catalog.setFlag(.reject)
    #expect(catalog.items == before)
    #expect(catalog.history.undo.isEmpty)
    #expect(catalog.cullError == "Couldn't set the flag: this window shows built-in sample data, not photos on disk.")
}
