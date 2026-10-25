// LibraryDeleteRejectsSpecTests.swift (cull-finish DR-u): Photo > Delete Rejected Photos… and its confirm's
// Move to Trash are built from one spec that is off with the window's reason and on without one, stays out of
// the agent catalog (the window asks first), and refuses to run as a command. Linux-safe.
@testable import LibraryModel
@testable import SuiteKernel
import Testing

@Suite struct LibraryDeleteRejectsSpecTests {
    @Test func availabilityIsTheItemHelp() {
        let spec = LibraryCatalog.deleteRejectsControlSpec
        #expect(spec.id == "photo.delete-rejects")
        #expect(spec.title == "Delete Rejected Photos…")
        #expect(spec.availability(LibraryDeleteRejectsControl(help: "No rejected photos in All Photos.")).why
            == "No rejected photos in All Photos.")
        #expect(spec.availability(LibraryDeleteRejectsControl(help: nil)).why == nil)
    }

    @Test func runSendsAnAgentToTheWindow() {
        var control = LibraryDeleteRejectsControl(help: nil)
        #expect(throws: CatalogError.unavailable(id: "photo.delete-rejects", why: LibraryCatalog.deleteRejectsInWindow)) {
            _ = try LibraryCatalog.deleteRejectsControlSpec.run(&control, .object([:]))
        }
    }

    @Test func staysOutOfTheCatalog() {
        #expect(!LibraryCatalog.catalog.ids.contains("photo.delete-rejects"))
    }
}
