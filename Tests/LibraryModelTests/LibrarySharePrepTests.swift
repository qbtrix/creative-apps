// LibrarySharePrepTests.swift: share-sheet's MJ-SH, what Share makes before the system's sheet opens: the
// preset, the folder rule, when Share can't run, the command's shape (SH-1), and the copies, their names, the
// location left out and the launch cleanup (SH-3), read through the fake exporter and writer. Linux and macOS.
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

    func writer(_ catalog: LibraryCatalog) throws -> FakeJPEGWriter {
        try #require(catalog.services.writer as? FakeJPEGWriter)
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
        #expect(shoot(selecting: ["IMG_0001"]).shareHelp == nil)
    }

    @Test func aPrepareThatCantRunSaysWhyAndWritesNothing() async throws {
        let catalog = shoot(selecting: [])
        await #expect(throws: LibraryRefusal("Select a photo to share it.")) {
            try await catalog.prepareShare(support: "/support", run: "r1")
        }
        #expect(try await writer(catalog).files.isEmpty)
    }

    @Test func theCommandTakesOptionalIDs() {
        let spec = LibraryCatalog.sharePrepareSpec
        #expect(spec.id == "file.share-prepare" && spec.kind == .file)
        #expect(spec.availability(shoot(selecting: [])) == .unavailable("Select a photo to share it."))
        #expect(LibraryCatalog.commands.contains { $0.id == "file.share-prepare" })
    }

    /// Mutation `.shareDropsLocation`: each copy is a JPEG at quality 85, long edge 2048, written without the
    /// location, serial numbers or maker notes, in the grid's order whatever order they were picked in.
    @Test func threePhotosGiveThreeJPEGsWithNoLocation() async throws {
        let catalog = shoot(selecting: ["IMG_0003", "IMG_0001", "IMG_0002"])
        let files = try await catalog.prepareShare(support: "/support", run: "r1")
        #expect(files == ["IMG_0001", "IMG_0002", "IMG_0003"].map { "/support/Share/r1/\($0).jpg" })
        let writer = try writer(catalog)
        let images = await writer.files, qualities = await writer.qualities, dropped = await writer.dropped
        #expect(Set(images.keys) == Set(files))
        for file in files {
            let size = try #require(images[file]?.size)
            #expect(max(size.width, size.height) == 2048, "\(file) is \(size), not long edge 2048")
            #expect(qualities[file] == 85)
            let gone = try #require(dropped[file], "\(file) was written without a metadata policy")
            #expect(gone == ExportRules.dropped(.noLocation).properties)
            #expect(gone.isSuperset(of: ["{GPS}", "{Exif}.MakerNote", "{Exif}.BodySerialNumber"]))
        }
        #expect(catalog.shareHelp == nil)
    }

    @Test func idsPickWhichPhotosAreShared() async throws {
        let catalog = shoot(selecting: ["IMG_0001", "IMG_0002", "IMG_0003"])
        let files = try await catalog.prepareShare(support: "/support", run: "r1", ids: [id("IMG_0003"), id("IMG_0002")])
        #expect(files == ["/support/Share/r1/IMG_0002.jpg", "/support/Share/r1/IMG_0003.jpg"])
    }

    @Test func twoPhotosNamedAlikeGetUniqueNames() async throws {
        let shoot = LibraryFixtures.photos(named: "shoot")
        let first = try #require(shoot.first), twin = try #require(shoot.dropFirst().first)
        let photos = [first, PhotoItem(id: twin.id, name: first.name, captureDate: twin.captureDate, color: twin.color,
                                       path: twin.path)]
        var catalog = LibraryCatalog(services: .fake(photos))
        catalog.load(photos)
        catalog.select([photos[0].id, photos[1].id])
        let files = try await catalog.prepareShare(support: "/support", run: "r1")
        #expect(files.count == 2 && Set(files).count == 2)
        #expect(Set(try await writer(catalog).files.keys) == Set(files))
    }

    /// The command names exactly the files the prepare writes for the same run.
    @Test func theCommandNamesTheFilesThePrepareWrites() async throws {
        var catalog = shoot(selecting: ["IMG_0002", "IMG_0001"])
        let params = JSONValue.object(["support": .string("/support"), "run": .string("r1")])
        let outcome = try LibraryCatalog.catalog.run("file.share-prepare", params: params, on: &catalog)
        let named = try outcome.result.decode(LibraryCatalog.ShareFiles.self).files
        #expect(named == ["/support/Share/r1/IMG_0001.jpg", "/support/Share/r1/IMG_0002.jpg"])
        #expect(try await catalog.prepareShare(support: "/support", run: "r1") == named)
    }

    /// Mutation `.shareFolderEmptiedAtLaunch`: every run's copies are gone after the launch cleanup.
    @Test func launchCleanupEmptiesTheShareFolder() async throws {
        let catalog = shoot(selecting: ["IMG_0001"])
        _ = try await catalog.prepareShare(support: "/support", run: "r1")
        _ = try await catalog.prepareShare(support: "/support", run: "r2")
        let writer = try writer(catalog)
        #expect(await writer.files.count == 2)
        try await SharePrep.cleanup(support: "/support", writer: writer)
        for run in ["r1", "r2"] {
            #expect(try await writer.existingNames(in: SharePrep.folder(support: "/support", run: run)).isEmpty)
        }
    }

    /// On disk the cleanup empties `<support>/Share/` and leaves the rest of the support folder alone.
    @Test func launchCleanupOnDiskKeepsTheCatalog() throws {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent("share-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: support) }
        try SharePrep.cleanup(support: support) // no Share folder yet: nothing to do
        let run = SharePrep.folder(support: support, run: "r1")
        try FileManager.default.createDirectory(atPath: run, withIntermediateDirectories: true)
        try Data([1]).write(to: URL(fileURLWithPath: run + "/IMG_0001.jpg"))
        try Data([2]).write(to: URL(fileURLWithPath: support + "/catalog.json"))
        try SharePrep.cleanup(support: support)
        #expect(try FileManager.default.contentsOfDirectory(atPath: support + "/Share").isEmpty)
        #expect(FileManager.default.fileExists(atPath: support + "/catalog.json"))
    }
}

/// RJ-L55 (SH-3c): the job's steps on the catalog as the window runs them, then the files the command named
/// written through the fake exporter and writer, checked against the job's expectations, and a relaunch's cleanup.
@Suite struct LibraryShareRealJobTests {
    struct Copy: Decodable { var longEdge: Int; var drops: [String] }

    @Test func shareThreeRealJobPasses() async throws {
        let folder = LibraryJob.root.appendingPathComponent("share-three")
        let script = try JSONDecoder().decode(LibraryJob.Script.self,
                                              from: Data(contentsOf: folder.appendingPathComponent("share-three.jobs.json")))
        var library = LibraryCatalog(services: .fake())
        var named: [String] = []
        for step in script.steps {
            guard case .object(var fields) = step.params else { continue }
            if case .array(let paths)? = fields["paths"] {
                fields["paths"] = .array(paths.map { if case .string(let p) = $0 { .string(folder.appendingPathComponent(p).path) } else { $0 } })
            }
            if case .string(let support)? = fields["support"] { fields["support"] = .string("/job/" + support) }
            let result = try LibraryCatalog.catalog.run(step.id, params: .object(fields), on: &library).result
            if step.id == "file.share-prepare" { named = try result.decode(LibraryCatalog.ShareFiles.self).files }
        }
        let written = try await library.prepareShare(support: "/job/out", run: "share-three")
        #expect(written == named && written.count == 3)
        let writer = try #require(library.services.writer as? FakeJPEGWriter)
        let images = await writer.files, dropped = await writer.dropped
        let copies = script.expect.filter { $0.key != "out/Share" }
        #expect(Set(copies.keys.map { "/job/" + $0 }) == Set(written))
        for (path, want) in copies {
            let copy = try want.decode(Copy.self), file = "/job/" + path
            let size = try #require(images[file]?.size, "\(file) wasn't written")
            #expect(max(size.width, size.height) == copy.longEdge)
            #expect(dropped[file]?.isSuperset(of: copy.drops) == true, "\(file) keeps some of \(copy.drops)")
        }
        try await SharePrep.cleanup(support: "/job/out", writer: writer)
        #expect(script.expect["out/Share"] == .object(["afterRelaunch": .array([])]))
        #expect(await writer.files.isEmpty, "Share/ still holds copies after a relaunch")
    }
}
