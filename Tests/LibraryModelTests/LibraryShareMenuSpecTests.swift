// LibraryShareMenuSpecTests.swift (share-sheet SH-u): File > Share…'s spec is off with the menu's reason and on
// without one, stays out of the agent catalog (the window shares), and sends an agent to `file.share-prepare`
// (share-sheet SH-5). Linux-safe.
@testable import LibraryModel
@testable import SuiteKernel
import Testing

@Suite struct LibraryShareMenuSpecTests {
    @Test func availabilityIsTheMenuHelp() {
        let spec = LibraryCatalog.shareMenuSpec
        #expect(spec.id == "file.share")
        #expect(spec.title == "Share…")
        #expect(spec.availability(LibraryShareMenu(help: "Select a photo to share it.")).why == "Select a photo to share it.")
        #expect(spec.availability(LibraryShareMenu(help: nil)).why == nil)
    }

    @Test func runSendsAnAgentToThePrepare() {
        var menu = LibraryShareMenu(help: nil)
        let why = "File > Share… opens the system's share sheet in the window; file.share-prepare makes the copies."
        #expect(throws: CatalogError.unavailable(id: "file.share", why: why)) {
            _ = try LibraryCatalog.shareMenuSpec.run(&menu, .object([:]))
        }
    }

    @Test func staysOutOfTheCatalog() {
        #expect(!LibraryCatalog.catalog.ids.contains("file.share"))
    }
}
