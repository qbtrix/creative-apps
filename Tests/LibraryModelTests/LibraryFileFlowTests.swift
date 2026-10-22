// LibraryFileFlowTests.swift: Library's file-flow adapter (file-flow LF-1, on
// LF-3). The routing and extensions, image hand-offs, a folder drop as one
// Import step that undoes at once, hand-offs to other apps, Open In from the
// loupe, and RJ-L42's steps. Runs on Linux and macOS.
import Foundation
@testable import LibraryModel
import SuiteKernel
import SuiteModel
import Testing

@Suite struct LibraryFileFlowTests {
    static var catalog: CommandCatalog<LibraryCatalog>? {
        try? CommandCatalog(app: "library", FileFlowCommands.specs(LibraryCatalog.self),
                            history: { _ in History<Int>() })
    }

    @Test func libraryIsAlwaysOpenAndPlacesWhatItImports() {
        let library = LibraryCatalog(services: .fake())
        #expect(library.appID == "library")
        #expect(library.hasDocument)
        #expect(library.recentFiles.isEmpty)
        #expect(library.placesExtensions == ["jpg", "jpeg", "png", "heic", "heif"])
    }

    @Test func readersFollowTheSuiteRegistry() {
        let library = LibraryCatalog(services: .fake())
        #expect(library.readers(ofExtension: "png").contains("library"))
        #expect(library.readers(ofExtension: "JPEG").contains("library"))
        #expect(library.readers(ofExtension: "halo") == ["halo"])
        #expect(library.readers(ofExtension: "zzz").isEmpty)
    }

    @Test func aDropPlansPlacesAndHandOffs() {
        let library = LibraryCatalog(services: .fake())
        let actions = DropPlan.plan(["/w/IMG_0001.jpg", "/w/Intro.halo", "/w/notes.zzz"], into: library.appID,
                                    hasDocument: library.hasDocument, places: library.placesExtensions,
                                    readers: library.readers(ofExtension:))
        #expect(actions.count == 3)
        #expect(actions.first == .place(path: "/w/IMG_0001.jpg"))
        #expect(actions.dropFirst().first == .handOff(path: "/w/Intro.halo", app: "halo"))
        if case .refuse = actions.last {} else { Issue.record("an unread type is refused") }
    }

    @Test func theFiveFileCommandsAreDeclared() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.ids == ["file.clear-recent", "file.drop", "file.open-in", "file.open-recent", "file.recent"])
        let library = LibraryCatalog(services: .fake())
        #expect(catalog.availability("file.open-in", on: library).why == LibraryCatalog.openInNeedsLoupe)
    }

    @Test func imageHandOffsAreAcceptedOthersRefused() async throws {
        let library = LibraryCatalog(services: .fake())
        for verb in [HandOffVerb.open, .place] {
            let handOff = HandOff(id: HandOff.newID(), from: .photo, to: .library, verb: verb, createdAt: Date())
            #expect(await library.refusal(for: handOff) == nil)
            #expect(try await library.accept(handOff) == .accepted)
        }
        let edit = HandOff(id: HandOff.newID(), from: .photo, to: .library, verb: .edit, createdAt: Date())
        #expect(await library.refusal(for: edit) == LibraryCatalog.handOffRefusal)
    }

    /// A folder of three photos on disk; `body` gets its path.
    static func withShoot(_ body: (String) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("lf-drop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["IMG_0001.jpg", "IMG_0002.jpg", "IMG_0003.jpg"] {
            try Data([0xFF, 0xD8, 0xFF]).write(to: folder.appendingPathComponent(name))
        }
        try body(folder.path)
    }

    /// LF-3: a dropped folder of three photos imports as one step and selects them; one Undo takes all three out.
    @Test func aFolderDropImportsAsOneStepAndSelects() throws {
        let catalog = try #require(Self.catalog)
        try Self.withShoot { folder in
            var library = LibraryCatalog(services: .fake())
            let steps = library.history.undo.count
            _ = try catalog.run("file.drop", params: .object(["paths": .array([.string(folder)])]), on: &library)
            #expect(library.items.count == 3)
            #expect(library.selection.count == 3)
            #expect(library.history.undo.count == steps + 1)
            #expect(library.undoTitle == "Undo Import")
            #expect(library.items.map(\.name).sorted() == ["IMG_0001", "IMG_0002", "IMG_0003"])
            library.undo()
            #expect(library.items.isEmpty && library.selection.isEmpty)
            library.redo()
            #expect(library.items.count == 3 && library.selection.count == 3)
            _ = try catalog.run("file.drop", params: .object(["paths": .array([.string(folder)])]), on: &library)
            #expect(library.items.count == 3, "a photo already in the catalog is not imported again")
        }
    }

    /// LF-3: another app's document goes to that app; nothing is imported.
    @Test func anotherAppsDocumentIsHandedOff() throws {
        var library = LibraryCatalog(services: .fake())
        try library.perform([.handOff(path: "/w/Intro.halo", app: "halo"), .refuse(path: "/w/a.zzz", reason: "No app opens it.")])
        #expect(library.items.isEmpty)
        #expect(library.history.undo.isEmpty)
        #expect(library.takeFileRequests() == [.handOff(path: "/w/Intro.halo", app: "halo"),
                                                .refused(path: "/w/a.zzz", reason: "No app opens it.")])
        #expect(library.takeFileRequests().isEmpty)
    }

    /// File > Open In ▸ Photo opens the loupe's photo in Photo.
    @Test func openInHandsTheLoupePhotoToPhoto() throws {
        let catalog = try #require(Self.catalog)
        try Self.withShoot { folder in
            var library = LibraryCatalog(services: .fake())
            try library.perform([.place(path: folder + "/IMG_0002.jpg")])
            #expect(library.openInHelp == LibraryCatalog.openInNeedsLoupe)
            #expect(library.openInApps.isEmpty)
            library.showLoupe()
            #expect(library.openInHelp == nil)
            #expect(library.openInApps.contains("photo") && !library.openInApps.contains("library"))
            _ = try catalog.run("file.open-in", params: .object(["app": .string("photo")]), on: &library)
            #expect(library.takeFileRequests() == [.handOff(path: folder + "/IMG_0002.jpg", app: "photo")])
        }
    }

    /// RJ-L42's steps, run on the catalog as the window runs them.
    @Test func dropImportRealJobPasses() throws {
        let folder = LibraryJob.root.appendingPathComponent("drop-import")
        let script = try JSONDecoder().decode(LibraryJob.Script.self,
                                              from: Data(contentsOf: folder.appendingPathComponent("drop-import.jobs.json")))
        var library = LibraryCatalog(services: .fake())
        var counts: [Int] = []
        for step in script.steps {
            var params = step.params
            if case .object(var fields) = params, case .array(let paths)? = fields["paths"] {
                fields["paths"] = .array(paths.map { if case .string(let p) = $0 { .string(folder.appendingPathComponent(p).path) } else { $0 } })
                params = .object(fields)
            }
            _ = try LibraryCatalog.catalog.run(step.id, params: params, on: &library)
            counts.append(library.items.count)
        }
        #expect(counts == [3, 0, 3])
        #expect(library.items.compactMap(\.path).map { URL(fileURLWithPath: $0).lastPathComponent }.sorted()
                == ["IMG_0001.jpg", "IMG_0002.jpg", "IMG_0003.jpg"])
        #expect(library.selection.count == 3)
        #expect(library.takeFileRequests() == [.handOff(path: folder.appendingPathComponent("input/Intro.halo").path, app: "halo")])
    }

    /// A recents entry for `path`, as the bridge lists it.
    static func entry(_ path: String, app: String = "library") -> RecentFileEntry {
        RecentFileEntry(fileID: SuiteDocumentRef.fileID(forPath: path), name: URL(fileURLWithPath: path).lastPathComponent,
                        path: path, app: app, lastUsed: Date(timeIntervalSince1970: 1))
    }

    /// LF-4: a loupe open is noted once, however often the window asks; a new photo or a reopen is noted again.
    @Test func aLoupeOpenIsNotedOncePerOpen() throws {
        try Self.withShoot { folder in
            var library = LibraryCatalog(services: .fake())
            var noted: [String?] = [library.takeLoupeOpen()?.path]  // no loupe photo, nothing to note
            try library.perform([.place(path: folder + "/IMG_0001.jpg"), .place(path: folder + "/IMG_0002.jpg")])
            noted.append(library.takeLoupeOpen()?.path)  // the grid notes nothing
            library.open(folder + "/IMG_0001.jpg")
            let first = library.takeLoupeOpen()
            let ref = try #require(first)
            #expect(ref.path == folder + "/IMG_0001.jpg" && ref.app == .library && ref.displayName == "IMG_0001.jpg")
            #expect(ref.fileID == SuiteDocumentRef.fileID(forPath: folder + "/IMG_0001.jpg"))
            noted.append(library.takeLoupeOpen()?.path)  // the same open, asked again
            library.stepLoupe(by: 1)
            noted.append(library.takeLoupeOpen()?.path)
            library.showGrid()
            noted.append(library.takeLoupeOpen()?.path)
            library.open(folder + "/IMG_0002.jpg")
            noted.append(library.takeLoupeOpen()?.path)  // a reopen after the grid is a new open
            #expect(noted == [nil, nil, nil, folder + "/IMG_0002.jpg", nil, folder + "/IMG_0002.jpg"])
        }
    }

    @Test func aSuiteRefOnlyForWhatLibraryReads() {
        #expect(LibraryCatalog.suiteRef("/w/a.PNG")?.type == SuiteTypeRegistry.standard.type(forExtension: "png")?.id)
        #expect(LibraryCatalog.suiteRef("/w/a.png")?.app == .library)
        #expect(LibraryCatalog.suiteRef("/w/Intro.halo") == nil)
        #expect(LibraryCatalog.suiteRef("/w/noext") == nil)
    }

    /// LF-4: Library's recent files are the suite list's Library entries; Open Recent opens one in the loupe.
    @Test func recentFilesFollowTheSuiteListAndOpenInTheLoupe() throws {
        let catalog = try #require(Self.catalog)
        try Self.withShoot { folder in
            var library = LibraryCatalog(services: .fake())
            try library.perform([.place(path: folder + "/IMG_0003.jpg")])
            let mine = Self.entry(folder + "/IMG_0003.jpg"), gone = Self.entry(folder + "/IMG_0009.jpg")
            library.updateFileFlow(recents: [mine, Self.entry("/w/Intro.halo", app: "halo"), gone])
            #expect(library.recentFiles == [mine, gone], "another app's entry is in Library's list")
            _ = try catalog.run("file.open-recent", params: .object(["fileID": .string(mine.fileID)]), on: &library)
            #expect(library.mode == .loupe && library.focusedItemID == folder + "/IMG_0003.jpg")
            #expect(throws: (any Error).self) { try library.openRecent(gone.fileID) }
            #expect(throws: (any Error).self) { try library.openRecent("nope") }
            try library.clearRecent()
            #expect(library.recentFiles.isEmpty)
        }
    }

    /// LF-4: the loupe's photo drags out as its file first, then the PNG the window made; nothing off the loupe.
    @Test func theLoupeDragsItsFileThenAPNG() throws {
        try Self.withShoot { folder in
            var library = LibraryCatalog(services: .fake())
            let png = Data([0x89, 0x50, 0x4E, 0x47])
            try library.perform([.place(path: folder + "/IMG_0001.jpg")])
            #expect(library.loupeDragItems(png: png, size: PixelSize(width: 4, height: 3)).isEmpty, "the grid has no loupe photo")
            library.showLoupe()
            let ref = try #require(library.loupeSuiteRef)
            #expect(library.loupeDragItems(png: png, size: PixelSize(width: 4, height: 3))
                    == [.files([ref]), .image(png: png, pixelWidth: 4, pixelHeight: 3)])
            #expect(library.loupeDragItems(png: nil, size: nil) == [.files([ref])], "no PNG: the file alone")
        }
    }
}
