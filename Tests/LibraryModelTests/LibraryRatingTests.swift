// LibraryRatingTests.swift: LibraryCatalog's cull (LibraryCulling.swift):
// the loupe photo or the selection takes the change as one named undo step,
// a refused change leaves no trace, and the cull keys map to their changes.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import LibraryModel
import Testing

/// Four unrated photos P1...P4 a day apart, in the grid, none selected.
private func fourPhotos(mode: FakeMode = .ok) -> LibraryCatalog {
    var catalog = LibraryCatalog(services: .fake(mode: mode))
    catalog.load((1...4).map {
        PhotoItem(
            name: "P\($0)", captureDate: Date(timeIntervalSince1970: 1_767_225_600 + Double($0) * 86_400),
            color: Color3(0, 0, 0))
    })
    return catalog
}

private func ratings(_ catalog: LibraryCatalog) -> [String: Int] {
    Dictionary(uniqueKeysWithValues: catalog.items.map { ($0.id, $0.rating) })
}

@Test func inTheLoupeACullChangesOnlyTheLoupePhoto() {
    var catalog = fourPhotos()
    catalog.select(["P1", "P2"])
    catalog.open("P3")
    #expect(catalog.cullTargets == ["P3"])
    catalog.cull(.rating(3))
    #expect(ratings(catalog) == ["P1": 0, "P2": 0, "P3": 3, "P4": 0])
    #expect(catalog.cullHelp == nil)
}

@Test func inTheGridACullChangesEverySelectedPhoto() {
    var catalog = fourPhotos()
    catalog.select(["P1", "P4"])
    #expect(catalog.cullTargets == ["P1", "P4"])
    catalog.cull(.rating(3))
    #expect(ratings(catalog) == ["P1": 3, "P2": 0, "P3": 0, "P4": 3])
}

@Test func oneCullIsOneNamedUndoStep() {
    let changes: [(CullChange, String)] = [
        (.rating(3), "Set Rating"), (.flag(.pick), "Pick"), (.flag(.reject), "Reject"),
        (.label(.green), "Set Label"),
    ]
    for (change, name) in changes {
        var catalog = fourPhotos()
        catalog.select(["P1", "P2", "P3"])
        catalog.cull(change)
        #expect(catalog.history.undo.count == 1)
        #expect(catalog.history.top?.name == name)
        #expect(catalog.undoTitle == "Undo " + name)
    }
    var catalog = fourPhotos()
    catalog.select(["P2"])
    catalog.cull(.flag(.pick))
    catalog.cull(.flag(.none))
    #expect(catalog.history.undo.map(\.name) == ["Pick", "Clear Flag"])
}

@Test func undoRestoresEveryPhotoExactly() {
    var catalog = fourPhotos()
    catalog.select(["P1", "P2"])
    catalog.cull(.rating(2))
    catalog.select(["P1", "P2", "P3"])
    let before = catalog.items
    catalog.cull(.rating(5))
    #expect(catalog.items != before)
    catalog.undo()
    #expect(catalog.items == before)
}

@Test func withNoTargetsNothingChanges() {
    var catalog = fourPhotos()
    let before = catalog
    #expect(catalog.cullTargets.isEmpty)
    #expect(catalog.cullHelp == "Select a photo to rate it.")
    catalog.cull(.rating(4))
    catalog.cull(.flag(.pick))
    #expect(catalog == before)
}

@Test func aRefusedCullLeavesNoTraceAndSaysWhy() {
    var catalog = fourPhotos(mode: .fail)
    catalog.select(["P1", "P2"])
    let items = catalog.items
    let history = catalog.history
    let revision = catalog.saveRevision
    catalog.cull(.rating(3))
    #expect(catalog.items == items)
    #expect(catalog.history == history)
    #expect(catalog.saveRevision == revision)
    #expect(catalog.cullError == "Couldn't set the rating: this window shows built-in sample data, not photos on disk.")
    catalog.dismissCullError()
    #expect(catalog.cullError == nil)
}

@Test func aRefusedCullNamesTheChangeAndSaysWhyInPlainWords() throws {
    let cases: [(CullChange, String)] = [
        (.rating(3), "Couldn't set the rating"),
        (.flag(.pick), "Couldn't set the flag"),
        (.flag(.reject), "Couldn't set the flag"),
        (.flag(.none), "Couldn't clear the flag"),
        (.label(nil), "Couldn't set the label"),
    ]
    for (change, opening) in cases {
        var catalog = fourPhotos(mode: .fail)
        catalog.select(["P1"])
        catalog.cull(change)
        let message = try #require(catalog.cullError)
        #expect(message.hasPrefix(opening), "\(change): \(message)")
        #expect(message.contains("sample data"), "\(change): \(message)")
        #expect(!message.lowercased().contains("preview"), "\(change): \(message)")
    }
}

@Test func aSuccessfulCullClearsTheError() {
    var catalog = fourPhotos()
    catalog.select(["P1"])
    catalog.cull(.rating(9))
    #expect(catalog.cullError == "A rating is 0 to 5 stars.")
    #expect(catalog.history.undo.isEmpty)
    catalog.cull(.rating(1))
    #expect(catalog.cullError == nil)
    #expect(ratings(catalog)["P1"] == 1)
}

@Test func autoAdvanceCanBeTurnedOffAndOn() {
    var catalog = fourPhotos()
    #expect(catalog.autoAdvance)
    catalog.setAutoAdvance(false)
    #expect(!catalog.autoAdvance)
    catalog.setAutoAdvance(true)
    #expect(catalog.autoAdvance)
}

@Test func cullKeysMapToTheirChanges() {
    #expect(LibraryCatalog.cullChange(for: .rating(3)) == .rating(3))
    #expect(LibraryCatalog.cullChange(for: .rating(0)) == .rating(0))
    #expect(LibraryCatalog.cullChange(for: .pick) == .flag(.pick))
    #expect(LibraryCatalog.cullChange(for: .reject) == .flag(.reject))
    #expect(LibraryCatalog.cullChange(for: .unflag) == .flag(.none))
    for key: LibraryKey in [.grid, .crop, .first, .last, .confirm] {
        #expect(LibraryCatalog.cullChange(for: key) == nil)
    }
}
