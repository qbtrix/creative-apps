// LibrarySharePrepTests.swift: share-sheet's MJ-SH, what Share makes before the system's sheet opens. The
// contract checks run now (the preset, the folder rule, when Share can't run, the command's shape); the
// copies, their names and the launch cleanup wait on SH-3 (contract rule 13, SH-1). Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct LibrarySharePrepTests {
    func id(_ name: String) -> String { "/fixture/shoot/\(name).jpg" }

    func shoot(selecting names: [String]) -> LibraryCatalog {
        let photos = LibraryFixtures.photos(named: "shoot")
        var catalog = LibraryCatalog(services: .fake(photos))
        catalog.load(photos)
        catalog.setSort(.name)
        catalog.select(Set(names.map(id)))
        return catalog
    }

    @Test func theCopiesAreTheSharingPresetWithLocationOff() {
        let options = SharePrep.options
        #expect(options.format == .jpeg && options.quality == 85 && options.longEdge == 2048)
        #expect(options.metadata == .noLocation)
        #expect(options.sidecar == false)
    }

    @Test func eachRunHasItsOwnFolderUnderShare() {
        #expect(SharePrep.folder(support: "/support", run: "r1") == "/support/Share/r1")
        #expect(SharePrep.folder(support: "/support/", run: "r2") == "/support/Share/r2")
    }

    @Test func shareSaysWhyItCantRun() {
        #expect(shoot(selecting: []).shareHelp == "Select a photo to share it.")
        var running = shoot(selecting: ["IMG_0001"])
        #expect(running.beginExport(folder: "/out") == true)
        #expect(running.exportPlan(existingNames: []) != nil)
        #expect(running.shareHelp == "An export is already running.")
        #expect(shoot(selecting: ["IMG_0001"]).shareHelp == SharePrep.notBuilt)
    }

    @Test func theStubsSayTheyArriveWithSH3() async {
        let catalog = shoot(selecting: ["IMG_0001"])
        await #expect(throws: LibraryNotBuilt(SharePrep.notBuilt)) {
            try await catalog.prepareShare(support: "/support", run: "r1")
        }
        #expect(throws: LibraryNotBuilt(SharePrep.notBuilt)) { try SharePrep.cleanup(support: "/support") }
    }

    @Test func theCommandTakesOptionalIDs() {
        let spec = LibraryCatalog.sharePrepareSpec
        #expect(spec.id == "file.share-prepare" && spec.kind == .file)
        #expect(spec.availability(shoot(selecting: [])) == .unavailable("Select a photo to share it."))
    }

    @Test(.disabled("waits on SH-3")) func threePhotosGiveThreeJPEGsWithNoLocation() async throws {
        let catalog = shoot(selecting: ["IMG_0003", "IMG_0001", "IMG_0002"])
        let files = try await catalog.prepareShare(support: "/support", run: "r1")
        #expect(files == ["IMG_0001", "IMG_0002", "IMG_0003"].map { "/support/Share/r1/\($0).jpg" })
        #expect(catalog.shareHelp == nil)
    }

    @Test(.disabled("waits on SH-3")) func twoPhotosNamedAlikeGetUniqueNames() async throws {
        let shoot = LibraryFixtures.photos(named: "shoot")
        let first = try #require(shoot.first), twin = try #require(shoot.dropFirst().first)
        let photos = [first, PhotoItem(id: twin.id, name: first.name, captureDate: twin.captureDate, color: twin.color,
                                       path: twin.path)]
        var catalog = LibraryCatalog(services: .fake(photos))
        catalog.load(photos)
        catalog.select([photos[0].id, photos[1].id])
        let files = try await catalog.prepareShare(support: "/support", run: "r1")
        #expect(files.count == 2 && Set(files).count == 2)
    }

    @Test(.disabled("waits on SH-3")) func launchCleanupEmptiesTheShareFolder() async throws {
        let catalog = shoot(selecting: ["IMG_0001"])
        _ = try await catalog.prepareShare(support: "/support", run: "r1")
        try SharePrep.cleanup(support: "/support")
        let writer = catalog.services.writer
        #expect(try await writer.existingNames(in: SharePrep.folder(support: "/support", run: "r1")).isEmpty)
    }
}
