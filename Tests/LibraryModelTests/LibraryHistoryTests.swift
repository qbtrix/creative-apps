// LibraryHistoryTests.swift: CatalogHistory, the undo and redo stacks of named
// before-and-after steps, coalescing a drag into one step, and the catalog's
// recordEdit, undo and redo. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

private func photo(_ name: String, rating: Int = 0) -> PhotoItem {
    PhotoItem(name: name, captureDate: Date(timeIntervalSince1970: 0), color: Color3(0, 0, 0), rating: rating)
}

private func step(_ name: String, from: Int, to: Int, key: String? = nil) -> CatalogHistory.Step {
    CatalogHistory.Step(
        name: name, before: [photo("A", rating: from)], after: [photo("A", rating: to)], coalesceKey: key)
}

@Test func anEmptyHistoryHasNoTop() {
    var history = CatalogHistory()
    #expect(history.top == nil)
    #expect(history.redoTop == nil)
    #expect(history.undo.isEmpty && history.redo.isEmpty)
    #expect(history.popUndo() == nil)
    #expect(history.popRedo() == nil)
    #expect(history == CatalogHistory())
}

@Test func popsGiveStepsBackInReverse() {
    var history = CatalogHistory()
    let first = step("Set Rating", from: 0, to: 1)
    let second = step("Pick", from: 1, to: 2)
    history.push(first)
    history.push(second)
    #expect(history.top == second)

    #expect(history.popUndo() == second)
    #expect(history.popUndo() == first)
    #expect(history.popUndo() == nil)
    #expect(history.redo == [second, first])

    #expect(history.popRedo() == first)
    #expect(history.popRedo() == second)
    #expect(history.popRedo() == nil)
    #expect(history.undo == [first, second])
}

@Test func aPushClearsRedo() {
    var history = CatalogHistory()
    history.push(step("Set Rating", from: 0, to: 1))
    _ = history.popUndo()
    #expect(history.redoTop?.name == "Set Rating")
    history.push(step("Pick", from: 0, to: 2))
    #expect(history.redo.isEmpty)
    #expect(history.undo.map(\.name) == ["Pick"])
}

@Test func anOpenCoalesceKeyKeepsOneStep() {
    var history = CatalogHistory()
    history.push(step("Exposure", from: 0, to: 1, key: "exposure"))
    history.push(step("Exposure", from: 1, to: 2, key: "exposure"))
    #expect(history.undo.count == 1)
    #expect(history.top?.before == [photo("A", rating: 0)])
    #expect(history.top?.after == [photo("A", rating: 2)])
    #expect(history.open)
}

@Test func coalescingStopsWhenClosedOrTheKeyDiffers() {
    var history = CatalogHistory()
    history.push(step("Exposure", from: 0, to: 1, key: "exposure"))
    history.endCoalescing()
    #expect(!history.open)
    history.push(step("Exposure", from: 1, to: 2, key: "exposure"))
    #expect(history.undo.count == 2)
    history.push(step("Contrast", from: 2, to: 3, key: "contrast"))
    #expect(history.undo.count == 3)
    history.push(step("Set Rating", from: 3, to: 4))
    history.push(step("Set Rating", from: 4, to: 5))
    #expect(history.undo.count == 5)
}

@Test func undoClosesCoalescing() {
    var history = CatalogHistory()
    history.push(step("Exposure", from: 0, to: 1, key: "exposure"))
    _ = history.popUndo()
    _ = history.popRedo()
    history.push(step("Exposure", from: 1, to: 2, key: "exposure"))
    #expect(history.undo.count == 2)
}

/// Three photos rated 1, 2 and 3 stars; P2 is open in the loupe and selected.
private func catalogWithLoupe() -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.load((1...3).map {
        PhotoItem(
            name: "P\($0)", captureDate: Date(timeIntervalSince1970: 1_767_225_600 + Double($0)),
            color: Color3(0, 0, 0), rating: $0)
    })
    catalog.open("P2")
    catalog.select(["P2"])
    return catalog
}

@Test func aRecordedRatingEditUndoesAndRedoesWithoutMovingTheLoupe() {
    var catalog = catalogWithLoupe()
    let original = catalog.items
    #expect(catalog.undoTitle == nil && catalog.redoTitle == nil)

    catalog.recordEdit("Set Rating", ids: ["P2"]) { $0.rating = 5 }
    #expect(catalog.undoTitle == "Undo Set Rating")
    #expect(catalog.items.map(\.rating) == [1, 5, 3])
    #expect(catalog.saveRevision == 1)
    let edited = catalog.items

    catalog.undo()
    #expect(catalog.items == original)
    #expect(catalog.mode == .loupe && catalog.focusedItemID == "P2")
    #expect(catalog.undoTitle == nil && catalog.redoTitle == "Redo Set Rating")
    #expect(catalog.saveRevision == 2)

    catalog.redo()
    #expect(catalog.items == edited)
    #expect(catalog.mode == .loupe && catalog.focusedItemID == "P2")
    #expect(catalog.undoTitle == "Undo Set Rating" && catalog.redoTitle == nil)
    #expect(catalog.saveRevision == 3)
}

@Test func editsWithOneCoalesceKeyAreOneStepUntilEndCoalescing() {
    var catalog = catalogWithLoupe()
    for stars in [4, 5, 0] {
        catalog.recordEdit("Set Rating", coalesceKey: "stars", ids: ["P1"]) { $0.rating = stars }
    }
    #expect(catalog.history.undo.count == 1)
    #expect(catalog.saveRevision == 3)
    catalog.endCoalescing()
    catalog.recordEdit("Set Rating", coalesceKey: "stars", ids: ["P1"]) { $0.rating = 2 }
    #expect(catalog.history.undo.count == 2)

    catalog.undo()
    catalog.undo()
    #expect(catalog.items.map(\.rating) == [1, 2, 3])
}

@Test func aNoOpEditRecordsNothing() {
    var catalog = catalogWithLoupe()
    catalog.recordEdit("Set Rating", ids: ["P3"]) { $0.rating = 3 }
    catalog.recordEdit("Set Rating", ids: []) { $0.rating = 0 }
    catalog.recordEdit("Set Rating", ids: ["missing"]) { $0.rating = 0 }
    #expect(catalog.undoTitle == nil)
    #expect(catalog.saveRevision == 0)
}

@Test func aNewEditClearsRedo() {
    var catalog = catalogWithLoupe()
    catalog.recordEdit("Set Rating", ids: ["P1"]) { $0.rating = 4 }
    catalog.undo()
    #expect(catalog.redoTitle == "Redo Set Rating")
    catalog.recordEdit("Pick", ids: ["P1"]) { $0.flag = .pick }
    #expect(catalog.redoTitle == nil)
    #expect(catalog.undoTitle == "Undo Pick")
    catalog.redo()
    #expect(catalog.items.map(\.rating) == [1, 2, 3])
    #expect(catalog.saveRevision == 3)
}

@Test func undoAndRedoWithNothingToDoChangeNothing() {
    var catalog = catalogWithLoupe()
    let before = catalog
    catalog.undo()
    catalog.redo()
    #expect(catalog == before)
}

@Test func undoingAnUnflagInFavoritesShowsThePhotoAgain() {
    var catalog = LibraryCatalog()
    catalog.load([
        PhotoItem(name: "F", captureDate: Date(timeIntervalSince1970: 0), color: Color3(0, 0, 0), isFlagged: true)
    ])
    catalog.selectCollection("favorites")
    catalog.select(["F"])
    catalog.recordEdit("Unflag", ids: ["F"]) { $0.flag = .none }
    #expect(catalog.order.isEmpty && catalog.selection.isEmpty)
    #expect(catalog.selectedCollection?.count == 0)
    catalog.undo()
    #expect(catalog.order == ["F"])
    #expect(catalog.selectedCollection?.count == 1)
}
