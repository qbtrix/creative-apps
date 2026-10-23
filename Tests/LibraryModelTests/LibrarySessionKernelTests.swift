// LibrarySessionKernelTests.swift: the catalog file on the kernel's
// DocumentSession (AD-l1): its tokens follow the catalog's revisions, an
// import dirties it with no undo step, a late save answer never moves it
// back, a save ends no drag, and the file's version is probed by
// VersionedJSON with its refusals as LibraryError. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import SuiteKernel
import Testing

/// Three photos rated 1, 2 and 3 stars, read from a file, so the catalog is saved.
private func savedCatalog() -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.beginRestore()
    catalog.restore((1...3).map {
        PhotoItem(
            name: "S\($0)", captureDate: Date(timeIntervalSince1970: 1_767_225_600 + Double($0)),
            color: Color3(0, 0, 0), rating: $0)
    })
    return catalog
}

@Test func theSessionTokensAreTheRevisionsAndAnUndoAfterASaveStaysDirty() throws {
    var catalog = savedCatalog()
    #expect(!catalog.catalogSession.isDirty && catalog.catalogSession.status == .saved)
    catalog.recordEdit("Set Rating", ids: [catalog.items[0].id]) { $0.rating = 5 }
    #expect(catalog.catalogSession.currentToken == catalog.saveRevision)
    #expect(catalog.catalogSession.savedToken == catalog.savedRevision)
    #expect(catalog.catalogSession.isDirty && catalog.catalogSession.status == .unsaved)
    let request = try #require(catalog.saveRequest())
    catalog.didSave(revision: request.revision)
    #expect(!catalog.catalogSession.isDirty && catalog.catalogValue == "saved")
    catalog.undo()  // the file holds the edit, so putting it back must be written
    #expect(catalog.catalogSession.isDirty && catalog.catalogValue == "dirty")
}

@Test func anImportDirtiesTheSessionWithNoUndoStep() {
    var catalog = savedCatalog()
    catalog.appendImported([
        PhotoItem(name: "New", captureDate: Date(timeIntervalSince1970: 1_767_300_000), color: Color3(0, 0, 0))
    ])
    #expect(catalog.history.undo.isEmpty)
    #expect(catalog.catalogSession.isDirty && catalog.catalogValue == "dirty")
}

@Test func aLateOlderSaveAnswerLeavesTheSessionDirty() throws {
    var catalog = savedCatalog()
    catalog.recordEdit("Set Rating", ids: [catalog.items[1].id]) { $0.rating = 4 }
    let first = try #require(catalog.saveRequest())
    catalog.recordEdit("Set Rating", ids: [catalog.items[1].id]) { $0.rating = 0 }
    catalog.didSave(revision: first.revision)
    #expect(catalog.catalogSession.isDirty)
    #expect(catalog.catalogSession.savedToken == first.revision)
}

@Test func aSaveBetweenTwoDragsKeepsThemTwoSteps() throws {
    var catalog = savedCatalog()
    let id = catalog.items[0].id
    for stars in [4, 5] {
        catalog.recordEdit("Set Rating", coalesceKey: "stars", ids: [id]) { $0.rating = stars }
    }
    catalog.endCoalescing()
    catalog.didSave(revision: try #require(catalog.saveRequest()).revision)
    catalog.recordEdit("Set Rating", coalesceKey: "stars", ids: [id]) { $0.rating = 2 }
    #expect(catalog.history.undo.count == 2)
    catalog.undo()  // back to the saved drag's end, not past it
    #expect(catalog.items.first { $0.id == id }?.rating == 5)
}

@Test func theSessionStatusIsFailedReadOnlyOrSaved() {
    var catalog = savedCatalog()
    catalog.recordEdit("Set Rating", ids: [catalog.items[2].id]) { $0.rating = 1 }
    catalog.failSave(.writeFailed(path: "/c/catalog.json", reason: "The disk is full."))
    #expect(catalog.catalogSession.status == .failed("The disk is full."))
    var newer = LibraryCatalog()
    newer.beginRestore()
    #expect(newer.catalogSession.status == .readOnly)
    newer.failRestore(.newerCatalog(version: 2))
    #expect(newer.catalogSession.status == .readOnly)
}

@Test func theVersionIsProbedByTheKernelWithItsRefusalsAsLibraryErrors() throws {
    #expect(try LiveCatalogCoding.probeVersion(Data(#"{"version": 1, "photos": []}"#.utf8)) == 1)
    #expect(throws: LibraryError.newerCatalog(version: 3)) {
        try LiveCatalogCoding.probeVersion(Data(#"{"version": 3}"#.utf8))
    }
    #expect(throws: LibraryError.damagedCatalog("")) { try LiveCatalogCoding.probeVersion(Data("[1]".utf8)) }
    #expect(throws: LibraryError.damagedCatalog("")) {
        try LiveCatalogCoding.probeVersion(Data(#"{"version": "1"}"#.utf8))
    }
}
