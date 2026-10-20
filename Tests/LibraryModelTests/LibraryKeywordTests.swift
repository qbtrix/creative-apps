// LibraryKeywordTests.swift: keywords on the cull targets (metadata-more MD-10). Written
// before its code (contract rule 13, MD-9), enabled by MD-10. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

/// Photos P1… with keywords, captured the given minutes after noon; `selected` by number.
private func catalog(_ photos: [([String], Double)], selected: [Int]) -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.load(photos.enumerated().map { index, photo in
        PhotoItem(
            name: "P\(index + 1)", captureDate: Date(timeIntervalSince1970: 1_780_315_200 + photo.1 * 60),
            color: Color3(0, 0, 0), keywords: photo.0)
    })
    catalog.select(Set(selected.map { "P\($0)" }))
    return catalog
}

private func keywords(_ catalog: LibraryCatalog) -> [[String]] { catalog.items.map(\.keywords) }

@Test func typedKeywordsAreNormalizedAndAddedInOneStep() {
    var three = catalog([([], 0), ([], 0), ([], 0)], selected: [1, 2, 3])
    three.addKeywords("beach,  Sunset ,beach")
    #expect(keywords(three) == Array(repeating: ["beach", "Sunset"], count: 3))
    #expect(three.history.undo.count == 1 && three.undoTitle == "Undo Add Keywords")
    three.addKeywords("  harbour   at dawn ,, ")
    #expect(three.items.allSatisfy { $0.keywords.contains("harbour at dawn") } && three.undoTitle == "Undo Add Keyword")
    var four = catalog([([], 0), ([], 0), ([], 0), (["Beach"], 0)], selected: [1, 2, 3])
    four.addKeywords("beach")
    #expect(keywords(four) == Array(repeating: ["Beach"], count: 4) && four.undoTitle == "Undo Add Keyword")
}

@Test func addingWhatEveryTargetHasRecordsNothing() {
    var two = catalog([(["Beach"], 0), (["Beach", "Sunset"], 0)], selected: [1, 2])
    two.addKeywords("BEACH")
    two.addKeywords(" , ")
    #expect(two.history.undo.isEmpty && keywords(two) == [["Beach"], ["Beach", "Sunset"]])
}

@Test func inTheLoupeTheLoupePhotoIsTheTarget() {
    var three = catalog([([], 0), ([], 0), ([], 0)], selected: [1, 2])
    three.open("P3")
    three.addKeywords("Pier")
    #expect(keywords(three) == [[], [], ["Pier"]])
}

@Test func aPartialKeywordBecomesWholeInOneStep() {
    var two = catalog([(["Beach", "Sunset"], 0), (["Beach"], 0)], selected: [1, 2])
    #expect(two.keywordStates == [.init(name: "Beach", count: 2, total: 2), .init(name: "Sunset", count: 1, total: 2)])
    two.addKeyword(toAll: "Sunset")
    #expect(keywords(two) == [["Beach", "Sunset"], ["Beach", "Sunset"]] && two.history.undo.count == 1)
    #expect(two.keywordStates.allSatisfy { !$0.isPartial } && two.undoTitle == "Undo Add Keyword")
}

@Test func removingIgnoresCaseAndUndoRestoresExactly() {
    var three = catalog([(["Beach", "Sunset"], 0), (["beach"], 0), (["Summer"], 0)], selected: [1, 2, 3])
    let before = three.items
    three.removeKeyword("BEACH")
    #expect(keywords(three) == [["Sunset"], [], ["Summer"]])
    #expect(three.history.undo.count == 1 && three.undoTitle == "Undo Remove Keyword")
    three.undo()
    #expect(three.items == before)
    three.redo()
    #expect(keywords(three)[1].isEmpty)
}

@Test func suggestionsRankByStartThenCompanyThenCount() {
    let one = catalog(  // P1 (Beach) is the target; Sunset keeps Beach company, Summer is on three photos
        [(["Beach"], 0), (["Beach", "Sunset"], 0), (["Summer"], 0), (["Summer"], 0), (["Late Summer", "Summer"], 0)],
        selected: [1])
    #expect(one.keywordSuggestions(prefix: "su") == ["Sunset", "Summer", "Late Summer"])
    #expect(one.keywordSuggestions(prefix: "SU", limit: 1) == ["Sunset"])
    #expect(!one.keywordSuggestions(prefix: "b").contains("Beach") && one.keywordSuggestions(prefix: "zz").isEmpty)
}

@Test func withNothingTypedPhotosFromTheSameHourComeFirst() {
    let one = catalog([([], 0), (["Harbour"], 30), (["Mountain"], 1_440), (["Mountain"], 1_440)], selected: [1])
    #expect(one.keywordSuggestions(prefix: "") == ["Harbour", "Mountain"])
}
