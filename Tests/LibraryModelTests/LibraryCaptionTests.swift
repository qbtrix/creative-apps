// LibraryCaptionTests.swift: title and caption on the selection (metadata-more MD-11).
// Written before its code (contract rule 13, MD-9); MD-11 turned them on. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

private func twoSelected(titles: [String] = ["", ""]) -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.load(titles.enumerated().map { index, title in
        PhotoItem(name: "P\(index + 1)", captureDate: .distantPast, color: Color3(0, 0, 0), title: title)
    })
    catalog.select(["P1", "P2"])
    return catalog
}

@Test func aTitleIsTrimmedAndSetInOneStepOnlyWhenItChanges() {
    var two = twoSelected()
    two.setTitle("  Harbour ")
    #expect(two.items.map(\.title) == ["Harbour", "Harbour"])
    #expect(two.history.undo.count == 1 && two.undoTitle == "Undo Set Title")
    #expect(two.selectedMetadata?.photoTitle == .value("Harbour"))
    two.setTitle("Harbour ")
    #expect(two.history.undo.count == 1)
}

@Test func differentTitlesReadMixed() throws {
    let metadata = try #require(twoSelected(titles: ["Harbour", ""]).selectedMetadata)
    #expect(metadata.photoTitle == .mixed && metadata.caption == .value(""))
}

@Test func aCaptionIsItsOwnStepAndUndoes() {
    var two = twoSelected()
    two.setTitle("Harbour")
    two.setCaption(" Low tide\n")
    #expect(two.items.map(\.caption) == ["Low tide", "Low tide"])
    #expect(two.history.undo.count == 2 && two.undoTitle == "Undo Set Caption")
    two.setCaption("Low tide")
    #expect(two.history.undo.count == 2)
    two.undo()
    #expect(two.items.map(\.caption) == ["", ""] && two.undoTitle == "Undo Set Title")
    two.undo()
    #expect(two.items.map(\.title) == ["", ""])
}

@Test func inTheLoupeOnlyTheLoupePhotoGetsTheTitleAndNothingSelectedRecordsNothing() {
    var two = twoSelected()
    two.open("P2")
    two.setTitle("\0Pier\t")
    #expect(two.items.map(\.title) == ["", "Pier"] && two.history.undo.count == 1)
    var none = twoSelected()
    none.select([])
    none.setCaption("Pier")
    #expect(none.items.map(\.caption) == ["", ""] && none.history.undo.isEmpty)
}
