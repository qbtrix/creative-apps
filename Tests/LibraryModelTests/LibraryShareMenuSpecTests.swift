// LibraryShareMenuSpecTests.swift (share-sheet SH-u): File > Share…'s spec is off with the menu's reason and on
// without one, and stays out of the agent catalog until the window can share. Linux-safe.
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct LibraryShareMenuSpecTests {
    @Test func availabilityIsTheMenuHelp() {
        let spec = LibraryCatalog.shareMenuSpec
        #expect(spec.id == "file.share")
        #expect(spec.title == "Share…")
        #expect(spec.availability(LibraryShareMenu(help: "Select a photo to share it.")).why == "Select a photo to share it.")
        #expect(spec.availability(LibraryShareMenu(help: nil)).why == nil)
    }

    @Test func staysOutOfTheCatalog() {
        #expect(!LibraryCatalog.catalog.ids.contains("file.share"))
    }
}
