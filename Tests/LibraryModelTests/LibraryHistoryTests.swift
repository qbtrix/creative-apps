// LibraryHistoryTests.swift: the catalog's recordEdit, undo and redo on the
// kernel's History: named steps, coalescing a drag into one step, the step
// limit and the open flag. The kernel's own tests cover History. Runs on
// Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

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

/// The collection counts by id.
private func counts(_ catalog: LibraryCatalog) -> [String: Int] {
    Dictionary(catalog.collections.map { ($0.id, $0.count) }, uniquingKeysWith: { first, _ in first })
}

/// The counts a full rescan of `catalog` gives.
private func rescannedCounts(_ catalog: LibraryCatalog) -> [String: Int] {
    var rescanned = catalog
    rescanned.recount()
    return counts(rescanned)
}

/// An edit, undo and redo move Favorites by the changed photos alone (#1587)
/// and leave All Photos and Recently Added as a full rescan has them.
@Test func editUndoAndRedoKeepEveryCollectionCountWithoutARescan() {
    var catalog = LibraryCatalog()
    catalog.load((0..<30).map { index in
        PhotoItem(
            name: "P\(index)", captureDate: Date(timeIntervalSince1970: Double(index)), color: Color3(0, 0, 0),
            isFlagged: index % 5 == 0)
    })
    let start = ["all": 30, "favorites": 6, "recent": 20]
    let picked = ["all": 30, "favorites": 7, "recent": 20]
    let unflagged = ["all": 30, "favorites": 4, "recent": 20]
    #expect(counts(catalog) == start)

    catalog.recordEdit("Pick", ids: ["P1"]) { $0.flag = .pick }  // one id: the plain scan
    #expect(counts(catalog) == picked)
    catalog.recordEdit("Unflag", ids: ["P0", "P2", "P5", "P10"]) { $0.flag = .none }  // several: the set
    #expect(counts(catalog) == unflagged)
    #expect(counts(catalog) == rescannedCounts(catalog))

    catalog.undo()
    #expect(counts(catalog) == picked)
    catalog.undo()
    #expect(counts(catalog) == start)
    catalog.redo()
    #expect(counts(catalog) == picked)
    catalog.redo()
    #expect(counts(catalog) == unflagged)
    #expect(counts(catalog) == rescannedCounts(catalog))
    #expect(catalog.items.filter(\.isFlagged).map(\.id) == ["P1", "P15", "P20", "P25"])
}

/// The kernel's 100-step limit: the 101st edit rolls the oldest into the base.
@Test func theCatalogKeepsAtMostAHundredSteps() {
    var catalog = catalogWithLoupe()
    for step in 0..<101 {
        catalog.recordEdit("Set Rating", ids: ["P1"]) { $0.rating = step % 2 == 0 ? 4 : 5 }
    }
    #expect(catalog.history.undo.count == 100)
    for _ in 0..<101 { catalog.undo() }
    #expect(catalog.undoTitle == nil)
    #expect(catalog.items.map(\.rating) == [4, 2, 3])
}

/// Undo and redo close an open drag, so the next sample is a step of its own.
@Test func undoAndRedoCloseTheOpenDrag() {
    var catalog = catalogWithLoupe()
    catalog.recordEdit("Exposure", coalesceKey: "exposure", ids: ["P1"]) { $0.rating = 4 }
    #expect(catalog.history.open)
    catalog.undo()
    #expect(!catalog.history.open)
    catalog.redo()
    #expect(!catalog.history.open)
    catalog.recordEdit("Exposure", coalesceKey: "exposure", ids: ["P1"]) { $0.rating = 5 }
    #expect(catalog.history.undo.count == 2)
    #expect(catalog.history.top?.photos.map(\.rating) == [4])
}
