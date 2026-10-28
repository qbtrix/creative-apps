// CatalogFilesControlsTests.swift (catalog-files LC-3): what the file controls read from the Model.
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct CatalogFilesControlsTests {
    @Test func largeMissingFixtureHasFiveHundredMissing() {
        var library = LibraryCatalog()
        library.load(LibraryFixtures.photos(named: "large-missing"))
        #expect(library.items.count == 10_000)
        #expect(library.missingCount == 500)
        #expect(LibraryCatalog.missingBadgeTitle(count: library.missingCount) == "500 photos are missing")
        #expect(LibraryCatalog.missingBadgeTitle(count: 1) == "1 photo is missing")
    }

    @Test func locateTargetPrefersTheSelectedMissingPhoto() {
        var library = LibraryCatalog()
        #expect(library.locateTarget == nil)
        library.load(LibraryFixtures.photos(named: "large-missing"))
        let missing = library.order.filter { id in library.items.contains { $0.id == id && $0.availability == .missing } }
        #expect(library.locateTarget == missing.first)
        library.select([missing[3], library.order[1]])
        #expect(library.locateTarget == missing[3])
        library.load(LibraryFixtures.photos(named: "large"))
        #expect(library.missingCount == 0)
        #expect(library.locateTarget == nil)
    }

    @Test func removeConfirmNamesTheCount() {
        #expect(LibraryCatalog.removeConfirmTitle(count: 3) == "Remove 3 Photos from the Catalog?")
        #expect(LibraryCatalog.removeConfirmTitle(count: 1) == "Remove 1 Photo from the Catalog?")
        #expect(LibraryCatalog.removeConfirmMessage.contains("files stay on disk"))
        var library = LibraryCatalog()
        library.load(LibraryFixtures.photos(named: "shoot"))
        library.select(Set(library.order.prefix(4)))
        #expect(library.removeCount == 4)
    }

    /// On an empty catalog both controls are off and say why, whether the stubs or LC-6's bodies answer.
    @Test func fileCommandsAreOffWithTheReason() {
        let library = LibraryCatalog()
        for id in ["photo.remove-from-catalog", "photo.relink"] {
            #expect(LibraryCatalog.fileSpec(id)?.id == id)
            #expect(LibraryCatalog.fileCommands.availability(id, on: library).why?.isEmpty == false)
        }
    }

    @Test func importCopySummarySaysWhereThePhotosGo() {
        #expect(ImportCopyOptions().summary == "Adds the photos where they are.")
        #expect(ImportCopyOptions(copyTo: "/Photos").summary == "Copies the photos into Photos.")
        #expect(ImportCopyOptions(copyTo: "/Photos", byDate: true).summary
            == "Copies the photos into Photos, in a folder for each day.")
    }
}
