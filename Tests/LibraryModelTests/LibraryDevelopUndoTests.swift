// LibraryDevelopUndoTests.swift: an undo or redo that moves a develop step
// names the photos whose settings it changed (`developChangedIDs`), so the
// window redraws the loupe and their thumbnails (#5953 step 5: Show Original
// toggled back to a picture the undo had never redrawn). A step that changes
// no develop names none. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

private func shot(_ n: Int) -> String { "/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }

private func shoot() -> LibraryCatalog {
    var catalog = LibraryCatalog(services: .fake())
    catalog.load(LibraryFixtures.photos(named: "shoot"))
    catalog.setSort(.name)
    return catalog
}

@Suite struct LibraryDevelopUndoTests {
    @Test func undoAndRedoOfADevelopStepNameItsPhotos() throws {
        var catalog = shoot()
        catalog.select([shot(1), shot(2)])
        catalog.setDevelop(.contrast, to: 13, coalesceKey: nil)
        catalog.undo()
        #expect(catalog.developChangedIDs == [shot(1), shot(2)])
        catalog.redo()
        #expect(catalog.developChangedIDs == [shot(1), shot(2)])
    }

    @Test func aStepWithoutDevelopNamesNone() throws {
        var catalog = shoot()
        catalog.select([shot(1)])
        catalog.setDevelop(.contrast, to: 13, coalesceKey: nil)
        catalog.undo()
        try catalog.run(.setRating(3))
        catalog.undo()
        #expect(catalog.developChangedIDs.isEmpty)
    }
}
