// LibraryCollectionsHistoryTests.swift: collection changes as steps in the
// catalog's undo history (FC-3): recordCollectionsEdit, undo and redo of the
// collections list, the selected collection's fallback, ordering with photo
// steps, the loupe and the save revision. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

/// Three photos; P2 is open in the loupe and selected.
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

private let keepers = UserCollection(id: "user-1", name: "Keepers", contents: .photos(["P1", "P2"]))

@Test func aCollectionsEditIsOneNamedStepAndANoOpRecordsNone() {
    var catalog = catalogWithLoupe()
    catalog.recordCollectionsEdit("New Collection") { $0.append(keepers) }
    #expect(catalog.userCollections == [keepers])
    #expect(catalog.history.undo.count == 1)
    #expect(catalog.undoTitle == "Undo New Collection")
    #expect(catalog.history.top?.collectionsBefore == [])
    #expect(catalog.history.top?.collectionsAfter == [keepers])
    #expect(catalog.collectionsRevision == 1)

    catalog.recordCollectionsEdit("Rename Collection") { $0 = $0.map { $0 } }
    #expect(catalog.history.undo.count == 1)
    #expect(catalog.undoTitle == "Undo New Collection")
    #expect(catalog.collectionsRevision == 1)
}

@Test func undoPutsTheListBackAndRedoTheNewOne() {
    var catalog = catalogWithLoupe()
    catalog.recordCollectionsEdit("New Collection") { $0.append(keepers) }
    catalog.recordCollectionsEdit("Rename Collection") { $0[0].name = "Best" }
    let renamed = catalog.userCollections
    #expect(renamed.map(\.name) == ["Best"])

    catalog.undo()
    #expect(catalog.userCollections == [keepers])
    #expect(catalog.redoTitle == "Redo Rename Collection")
    catalog.undo()
    #expect(catalog.userCollections.isEmpty)
    #expect(catalog.undoTitle == nil)

    catalog.redo()
    #expect(catalog.userCollections == [keepers])
    catalog.redo()
    #expect(catalog.userCollections == renamed)
    #expect(catalog.redoTitle == nil && catalog.undoTitle == "Undo Rename Collection")
    #expect(catalog.collectionsRevision == 6)
}

@Test func undoOfASelectedNewCollectionFallsBackToAllPhotos() {
    var catalog = catalogWithLoupe()
    catalog.recordCollectionsEdit("New Collection") { $0.append(keepers) }
    catalog.selectedCollectionID = "user-1"
    catalog.undo()
    #expect(catalog.userCollections.isEmpty)
    #expect(catalog.selectedCollectionID == "all")
    #expect(catalog.order == ["P1", "P2", "P3"])
    // The fallback keeps the selection; picking All Photos by hand would clear it.
    #expect(catalog.selection == ["P2"])
}

@Test func photoAndCollectionStepsUndoInOrder() {
    var catalog = catalogWithLoupe()
    catalog.recordEdit("Set Rating", ids: ["P2"]) { $0.rating = 5 }
    catalog.recordCollectionsEdit("New Collection") { $0.append(keepers) }
    #expect(catalog.history.undo.map(\.name) == ["Set Rating", "New Collection"])

    catalog.undo()
    #expect(catalog.userCollections.isEmpty)
    #expect(catalog.items.map(\.rating) == [1, 5, 3])
    catalog.undo()
    #expect(catalog.items.map(\.rating) == [1, 2, 3])
    #expect(catalog.userCollections.isEmpty)

    catalog.redo()
    #expect(catalog.items.map(\.rating) == [1, 5, 3])
    #expect(catalog.userCollections.isEmpty)
    catalog.redo()
    #expect(catalog.userCollections == [keepers])
    #expect(catalog.items.map(\.rating) == [1, 5, 3])
}

@Test func undoAndRedoOfACollectionsStepNeverMoveTheLoupe() {
    var catalog = catalogWithLoupe()
    catalog.recordCollectionsEdit("New Collection") { $0.append(keepers) }
    #expect(catalog.mode == .loupe && catalog.focusedItemID == "P2")
    catalog.undo()
    #expect(catalog.mode == .loupe && catalog.focusedItemID == "P2")
    catalog.redo()
    #expect(catalog.mode == .loupe && catalog.focusedItemID == "P2")
}

@Test func aCollectionsOnlyStepLeavesSaveRevisionAlone() {
    var catalog = catalogWithLoupe()
    catalog.recordCollectionsEdit("New Collection") { $0.append(keepers) }
    catalog.undo()
    catalog.redo()
    #expect(catalog.saveRevision == 0)
    #expect(catalog.collectionsRevision == 3)
}
