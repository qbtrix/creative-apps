// LibraryImportTests.swift: the catalog's import state machine (import IM-1):
// beginImport, progress, batches that skip known ids, finish, fail, dismiss
// and the Import Folder… help. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

private func shot(_ path: String, day: Double = 0) -> PhotoItem {
    PhotoItem(id: path, name: path, captureDate: Date(timeIntervalSince1970: day * 86_400),
              color: Color3(0.5, 0.5, 0.5), path: path)
}

private func catalog(_ paths: [String]) -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.load(paths.enumerated().map { shot($1, day: Double($0)) })
    return catalog
}

private func allCount(_ catalog: LibraryCatalog) -> Int? {
    catalog.collections.first { $0.id == "all" }?.count
}

@Test func beginImportReturnsEveryIDAndRuns() {
    var library = catalog(["/a.jpg", "/b.jpg"])
    library.failImport(.noPhotos("Old"), folder: "Old")
    #expect(library.importNotice != nil)
    #expect(library.beginImport() == ["/a.jpg", "/b.jpg"])
    #expect(library.importState == .running(ImportProgress(done: 0, total: 0)))
    #expect(library.importNotice == nil)
}

@Test func aSecondBeginReturnsNilUntilFinish() {
    var library = catalog(["/a.jpg"])
    #expect(library.beginImport() != nil)
    #expect(library.beginImport() == nil)
    library.showImportProgress(ImportProgress(done: 2, total: 5))
    #expect(library.importState == .running(ImportProgress(done: 2, total: 5)))
    #expect(library.beginImport() == nil)
    library.finishImport(ImportResult(added: [], alreadyKnown: 1, failures: []), folder: "Shots")
    #expect(library.importState == .idle)
    #expect(library.beginImport() == ["/a.jpg"])
}

@Test func beginImportWaitsForTheCatalogToLoad() {
    var library = catalog(["/a.jpg"])
    library.catalogState = .loading
    #expect(library.beginImport() == nil)
    #expect(library.importState == .idle)
    library.catalogState = .ready
    #expect(library.beginImport() == ["/a.jpg"])
}

@Test func progressOutsideAnImportIsIgnored() {
    var library = catalog([])
    library.showImportProgress(ImportProgress(done: 1, total: 3))
    #expect(library.importState == .idle)
}

@Test func appendImportedAddsOnlyNewIDs() {
    var library = catalog(["/b.jpg"])
    let revision = library.saveRevision
    _ = library.beginImport()
    library.appendImported([shot("/b.jpg", day: 9), shot("/c.jpg", day: 2), shot("/a.jpg", day: -1),
                            shot("/c.jpg", day: 3)])
    #expect(library.items.map(\.id).sorted() == ["/a.jpg", "/b.jpg", "/c.jpg"])
    #expect(library.items.first { $0.id == "/b.jpg" }?.captureDate == Date(timeIntervalSince1970: 0))
    #expect(allCount(library) == 3)
    #expect(library.order == ["/a.jpg", "/b.jpg", "/c.jpg"])
    #expect(library.saveRevision == revision + 1)
}

@Test func finishImportSetsTheNoticeAndGoesIdle() {
    var library = catalog(["/known.jpg"])
    _ = library.beginImport()
    let added = (0..<26).map { shot("/shots/\($0).jpg", day: Double($0)) }
    library.appendImported(Array(added.prefix(10)))
    let failure = FileFailure(path: "/shots/broken.jpg", reason: "not an image file")
    library.finishImport(ImportResult(added: added, alreadyKnown: 1, failures: [failure]), folder: "Shots")
    #expect(library.importState == .idle)
    #expect(library.items.count == 27)
    #expect(allCount(library) == 27)
    #expect(library.importNotice == ImportNotice(folder: "Shots", added: 26, alreadyKnown: 1, failures: [failure]))
    #expect(library.importNotice?.message == "Imported 26 photos. 1 file couldn't be imported.")
    #expect(library.importNotice?.isError == false)
}

@Test func failImportGivesTheErrorNotice() {
    var library = catalog(["/a.jpg"])
    _ = library.beginImport()
    library.failImport(.unreadableFolder("Shots"), folder: "Shots")
    #expect(library.importState == .idle)
    #expect(library.importNotice == ImportNotice(folder: "Shots", error: .unreadableFolder("Shots")))
    #expect(library.importNotice?.message == "Library can't read Shots. Check that you have access to it.")
    #expect(library.importNotice?.isError == true)
    #expect(library.items.count == 1)
    library.dismissImportNotice()
    #expect(library.importNotice == nil)
}

@Test func anImportIsNeverAnUndoStep() {
    var library = catalog(["/a.jpg"])
    library.select(["/a.jpg"])
    library.recordEdit("Set Rating", ids: ["/a.jpg"]) { $0.rating = 3 }
    let title = library.undoTitle
    let history = library.history
    _ = library.beginImport()
    library.appendImported([shot("/b.jpg")])
    library.finishImport(ImportResult(added: [shot("/b.jpg"), shot("/c.jpg")], alreadyKnown: 0, failures: []),
                         folder: "Shots")
    #expect(library.undoTitle == title)
    #expect(library.history == history)
    #expect(library.items.count == 3)
}

@Test func importHelpSaysAnImportIsRunning() {
    var library = catalog([])
    #expect(library.importHelp == LiveImporter.unavailable)
    _ = library.beginImport()
    #expect(library.importHelp == "An import is already running.")
    library.failImport(.noPhotos("Shots"), folder: "Shots")
    #expect(library.importHelp == LiveImporter.unavailable)
}
