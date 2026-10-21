// LibraryLabelKeysTests.swift: keys 6–9 set a color label (cull-finish DR-5).
// Each key is one "Set Label" step on the cull targets, a label never moves
// the loupe on, and the rating and flag keys keep their changes. Runs on
// Linux and macOS.
import Testing
@testable import LibraryModel

private func shot(_ n: Int) -> String { "/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }

@Test func labelKeysMapToTheirLabels() {
    let expected: [(Character, PhotoLabel)] = [("6", .red), ("7", .yellow), ("8", .green), ("9", .blue)]
    for (character, label) in expected {
        let key = LibraryKey(character: character)
        #expect(key == .label(label))
        #expect(key.flatMap(LibraryCatalog.cullChange(for:)) == .label(label))
    }
}

@Test func eachLabelKeyIsOneStepAndNeverAdvances() {
    var catalog = LibraryCatalog(services: .fake())
    catalog.load(LibraryFixtures.photos(named: "shoot"))
    catalog.setSort(.name)
    catalog.open(shot(1))
    catalog.setAutoAdvance(true)
    for (_, label) in LibraryKey.labelKeys {
        let steps = catalog.history.undo.count
        guard let change = LibraryCatalog.cullChange(for: .label(label)) else {
            Issue.record("no change for \(label)"); continue
        }
        catalog.cull(change)
        #expect(catalog.items.first { $0.id == shot(1) }?.label == label)
        #expect(catalog.history.undo.count == steps + 1)
        #expect(catalog.history.top?.name == "Set Label")
        #expect(catalog.focusedItemID == shot(1))
        #expect(catalog.mode == .loupe)
    }
    catalog.undo()
    #expect(catalog.items.first { $0.id == shot(1) }?.label == .green)
}

@Test func aLabelKeyInTheGridLabelsTheSelectionAsOneStep() {
    var catalog = LibraryCatalog(services: .fake())
    catalog.load(LibraryFixtures.photos(named: "shoot"))
    catalog.select([shot(2), shot(3)])
    let steps = catalog.history.undo.count
    guard let change = LibraryKey(character: "9").flatMap(LibraryCatalog.cullChange(for:)) else {
        Issue.record("9 has no change"); return
    }
    catalog.cull(change)
    #expect(catalog.items.filter { [shot(2), shot(3)].contains($0.id) }.allSatisfy { $0.label == .blue })
    #expect(catalog.items.first { $0.id == shot(1) }?.label != .blue)
    #expect(catalog.history.undo.count == steps + 1)
    #expect(catalog.mode == .grid)
}

@Test func theRatingAndFlagKeysKeepTheirChanges() {
    for stars in 0...5 {
        #expect(LibraryCatalog.cullChange(for: .rating(stars)) == .rating(stars))
    }
    #expect(LibraryKey(character: "p").flatMap(LibraryCatalog.cullChange(for:)) == .flag(.pick))
    #expect(LibraryKey(character: "x").flatMap(LibraryCatalog.cullChange(for:)) == .flag(.reject))
    #expect(LibraryKey(character: "u").flatMap(LibraryCatalog.cullChange(for:)) == .flag(.none))
    #expect(LibraryCatalog.cullChange(for: .grid) == nil)
}
