// HaloFileFlowTests.swift: MHF, Halo's file-flow Model walk (file-flow
// HF-1 written, HF-3 turns it on). HaloProject as a FileFlowTarget, with
// HaloDocumentHost as its suite document host: it names itself "halo", opens
// a dropped .halo through the host, hands a PNG to Photo (image layers are
// S20), imports its old Open Recent list once, and a drop that opens or
// hands off changes no document. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HaloModel
import SuiteKernel
import SuiteModel
import Testing

/// A project with one empty composition, on fakes.
private func opened() throws -> HaloProject {
    HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
}

/// The commands a host delivered, in order.
private actor Delivered {
    private(set) var commands: [HaloCommand] = []
    func record(_ command: HaloCommand) { commands.append(command) }
}

/// What the adapter answers on its own: its name, what it places, its readers and Open In.
@Suite struct HaloFileFlowAnswerTests {
    @Test func haloNamesItselfAndPlacesNothingYet() {
        let project = HaloProject(services: .fake)
        #expect(project.appID == "halo")
        #expect(project.placesExtensions.isEmpty)
        #expect(HaloProject.imageRefusal == "Halo can't place images yet.")
    }

    @Test func hasDocumentFollowsTheComposition() throws {
        #expect(!HaloProject(services: .fake).hasDocument)
        #expect(try opened().hasDocument)
    }

    @Test func aHaloIsReadByHaloAndAPNGByPhotoFirst() {
        let project = HaloProject(services: .fake)
        #expect(project.readers(ofExtension: "halo") == ["halo"])
        #expect(project.readers(ofExtension: "png").first == "photo")
        #expect(project.readers(ofExtension: "nope").isEmpty)
    }

    @Test func openInSaysNoOtherAppReadsAHalo() throws {
        var project = try opened()
        #expect(project.suiteDocument == nil, "an unsaved project hands Open In a document")
        #expect(project.openInApps.isEmpty && project.openInHelp == "No other app opens Halo Project files.")
        #expect(throws: CatalogError.self) { try project.openIn("flare") }
        project.didSave(name: "Intro.halo", path: "/w/Intro.halo")
        let document = try #require(project.suiteDocument)
        #expect(document.app == .halo && document.type == .haloProject && document.displayName == "Intro.halo")
        #expect(document.fileID == SuiteDocumentRef.fileID(forPath: "/w/Intro.halo"))
    }

    @Test func recentsComeFromTheWindowAndClearMenuEmptiesThem() throws {
        var project = try opened()
        let entry = RecentFileEntry(fileID: "path:/nowhere/Gone.halo", name: "Gone.halo", path: "/nowhere/Gone.halo",
                                    app: "halo", lastUsed: Date(timeIntervalSince1970: 0))
        project.updateFileFlow(recents: [entry])
        #expect(project.recentFiles == [entry])
        #expect(throws: CatalogError.self) { try project.openRecent(entry.fileID) }
        #expect(project.recentFiles.isEmpty, "a missing file stayed in Open Recent")
        #expect(project.takeFileRequests() == [.forget(fileID: entry.fileID)])
        project.updateFileFlow(recents: [entry])
        try project.clearRecent()
        #expect(project.recentFiles.isEmpty && project.takeFileRequests() == [.clearRecent])
    }

    @Test func theCatalogRunsTheSuiteFileFlow() throws {
        let ids = Set(HaloProject.commandSpecs.map(\.id))
        #expect(["file.recent", "file.open-recent", "file.clear-recent", "file.open-in", "file.drop"].allSatisfy(ids.contains))
        #expect(HaloProject.commandSpecs.filter { $0.id == "file.open-recent" }.count == 1)
    }
}

/// MHF, the behaviour HF-3 turns on.
@Suite struct HaloFileFlowTests {
    /// The drop rule for `paths` into `target`.
    private func plan(_ target: HaloProject, _ paths: String...) -> [DropAction] {
        DropPlan.plan(paths, into: target.appID, hasDocument: target.hasDocument,
                      places: target.placesExtensions, readers: { target.readers(ofExtension: $0) })
    }

    @Test func aHaloOpensThroughTheHost() async throws {
        let project = try opened()
        #expect(plan(project, "/w/Promo.halo") == [.open(path: "/w/Promo.halo")])
        let delivered = Delivered()
        let host = HaloDocumentHost { await delivered.record($0) }
        let ref = SuiteDocumentRef(path: "/w/Promo.halo", fileID: SuiteDocumentRef.fileID(forPath: "/w/Promo.halo"),
                                   app: .halo, type: .haloProject, displayName: "Promo.halo")
        let handOff = HandOff(id: HandOff.newID(), from: .halo, to: .halo, verb: .open, documents: [ref],
                              createdAt: Date(timeIntervalSince1970: 0))
        #expect(try await host.accept(handOff) == .accepted)
        #expect(await delivered.commands == [.openRecent("/w/Promo.halo")])
    }

    @Test func aPNGHandsOffToPhoto() throws {
        let project = try opened()
        #expect(plan(project, "/w/Sunset.png") == [.handOff(path: "/w/Sunset.png", app: "photo")])
    }

    @Test func theOldRecentsAreImportedOnce() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("HaloFileFlow-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let recents = StoreRecents(store: FileStore(folder: folder.path))
        var stored: [HaloRecentFile]? = [HaloRecentFile(name: "Intro.halo", path: "/w/Intro.halo"),
                                         HaloRecentFile(name: "Spot.halo", path: "/w/Spot.halo")]
        for round in 0..<2 {
            let refs = HaloProject.takeOldRecents(&stored)
            if round == 1 { #expect(refs.isEmpty, "the old list was imported twice") }
            for (i, ref) in refs.enumerated() {
                try await recents.note(ref, event: .opened, at: Date(timeIntervalSince1970: Double(i)), thumbnail: nil)
            }
        }
        #expect(stored == nil)
        let items = try await recents.list().items
        #expect(items.map(\.ref.path) == ["/w/Intro.halo", "/w/Spot.halo"])
        #expect(items.allSatisfy { $0.ref.app == .halo && $0.ref.type == .haloProject })
    }

    @Test func aDropThatOpensOrHandsOffChangesNoDocument() throws {
        var project = try opened()
        let before = project.document
        try project.perform(plan(project, "/w/Promo.halo", "/w/Sunset.png"))
        #expect(project.document == before)
        #expect(project.takeFileRequests() == [.open(path: "/w/Promo.halo"), .handOff(path: "/w/Sunset.png", app: "photo")])
        #expect(project.undoTitle == nil, "a drop left an undo step")
    }
}
