// LibraryDeleteRejectsTests.swift: Photo > Delete Rejected Photos…
// (cull-finish DR-6). The rejects move to the Trash and leave the catalog as
// one "Delete Rejects" step; undo puts files and photos back where they sat;
// a photo whose move fails stays and is named; a re-import skips what was
// trashed. Off by name until DR-6 gives `deleteRejects` its body. Runs on
// Linux and macOS.
import Testing
@testable import LibraryModel

private let rejected = [1, 4, 7]  // IMG_0002, IMG_0005, IMG_0008

/// The shoot with three rejects, on a FakeTrash the test keeps.
private func shootWithRejects(_ trash: FakeTrash = FakeTrash()) -> LibraryCatalog {
    var photos = LibraryFixtures.shoot()
    for index in rejected { photos[index].flag = .reject }
    var services = LibraryServices.fake(photos)
    services.trash = trash
    var catalog = LibraryCatalog(services: services)
    catalog.load(photos)
    return catalog
}

@Test(.disabled("DR-6")) func deleteRejectsTrashesThemAsOneStep() {
    let trash = FakeTrash()
    var catalog = shootWithRejects(trash)
    let kept = catalog.items.filter { $0.flag != .reject }.map(\.id)
    #expect(catalog.deleteRejectsHelp == nil)
    catalog.deleteRejects()
    #expect(catalog.items.map(\.id) == kept)
    #expect(catalog.items.count == 21)
    #expect(catalog.history.undo.map(\.name).last == "Delete Rejects")
    #expect(trash.moved.count == 3)
    #expect(catalog.deleteRejectsTargets.isEmpty)
}

@Test(.disabled("DR-6")) func undoPutsEachPhotoBackWhereItSat() {
    let trash = FakeTrash()
    var catalog = shootWithRejects(trash)
    let before = catalog.items.map(\.id)
    catalog.deleteRejects()
    catalog.undo()
    #expect(catalog.items.map(\.id) == before)
    #expect(trash.moved.isEmpty)
    catalog.redo()
    #expect(catalog.items.count == 21)
    #expect(trash.moved.count == 3)
}

@Test(.disabled("DR-6")) func aFailedMoveKeepsThatPhotoAndNamesIt() {
    let trash = FakeTrash(failing: ["/fixture/shoot/IMG_0005.jpg"])
    var catalog = shootWithRejects(trash)
    catalog.deleteRejects()
    #expect(catalog.items.count == 22)
    #expect(catalog.items.contains { $0.name == "IMG_0005" })
    #expect(catalog.cullError?.contains("IMG_0005") == true)
}

@Test(.disabled("DR-6")) func aFailedPutBackLeavesThePhotoOutAndSaysSo() {
    let trash = FakeTrash()
    var catalog = shootWithRejects(trash)
    catalog.deleteRejects()
    // Empty the Trash behind the catalog's back: the put-back has nothing to move.
    for (trashed, original) in trash.moved where original.hasSuffix("IMG_0008.jpg") {
        try? trash.putBack(trashed, to: original)
    }
    catalog.undo()
    #expect(catalog.items.count == 23)
    #expect(!catalog.items.contains { $0.name == "IMG_0008" })
    #expect(catalog.cullError?.contains("IMG_0008") == true)
}

@Test(.disabled("DR-6")) func aSamplePhotoLeavesWithoutATrashCall() {
    let trash = FakeTrash()
    var photos = LibraryFixtures.photos(named: "samples")
    guard !photos.isEmpty else { Issue.record("no samples"); return }
    photos[0].flag = .reject
    var services = LibraryServices.fake(photos)
    services.trash = trash
    var catalog = LibraryCatalog(services: services)
    catalog.load(photos)
    #expect(photos[0].path == nil)
    catalog.deleteRejects()
    #expect(catalog.items.count == photos.count - 1)
    #expect(trash.moved.isEmpty)
}

@Test func noRejectsDisablesTheCommandWithItsHelp() {
    var catalog = LibraryCatalog(services: .fake())
    catalog.load(LibraryFixtures.shoot())
    let steps = catalog.history.undo.count
    #expect(catalog.deleteRejectsHelp?.hasPrefix("No rejected photos in ") == true)
    catalog.deleteRejects()
    #expect(catalog.items.count == 24)
    #expect(catalog.history.undo.count == steps)
}

@Test(.disabled("DR-6")) func aReimportSkipsTheTrashedPaths() {
    var catalog = shootWithRejects()
    catalog.deleteRejects()
    let skip = catalog.beginImport() ?? []
    for n in [2, 5, 8] {
        #expect(skip.contains("/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg"))
    }
}
