// LibraryFileFlowTests.swift: Library's file-flow adapter (file-flow LF-1, on
// at LF-3). LF-1 pins the routing, the extensions and the refusals; the drop
// tests stay off by name until LF-3 gives the actions bodies. Runs on Linux
// and macOS.
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
        #expect(catalog.availability("file.open-in", on: library).why == LibraryCatalog.fileFlowUnavailable)
    }

    @Test func untilLF3EveryActionRefusesWithItsReason() async {
        var library = LibraryCatalog(services: .fake())
        let handOff = HandOff(id: HandOff.newID(), from: .photo, to: .library, verb: .open, createdAt: Date())
        #expect(await library.refusal(for: handOff) == .notAvailable(LibraryCatalog.fileFlowUnavailable))
        #expect(throws: LibraryError.self) { try library.perform([.place(path: "/w/IMG_0001.jpg")]) }
        #expect(throws: LibraryError.self) { try library.openIn("photo") }
        #expect(throws: LibraryError.self) { try library.openRecent("path:/w/a.jpg") }
        #expect(library.items.isEmpty)
    }

    /// LF-3: a dropped folder of three photos imports as one step and selects them.
    @Test(.disabled("LF-3")) func aFolderDropImportsAsOneStepAndSelects() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("lf-drop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["IMG_0001.jpg", "IMG_0002.jpg", "IMG_0003.jpg"] {
            try Data([0xFF, 0xD8, 0xFF]).write(to: folder.appendingPathComponent(name))
        }
        let catalog = try #require(Self.catalog)
        var library = LibraryCatalog(services: .fake())
        let steps = library.history.undo.count
        _ = try catalog.run("file.drop", params: .object(["paths": .array([.string(folder.path)])]), on: &library)
        #expect(library.items.count == 3)
        #expect(library.selection.count == 3)
        #expect(library.history.undo.count == steps + 1)
    }

    /// LF-3: another app's document goes to that app; nothing is imported.
    @Test(.disabled("LF-3")) func anotherAppsDocumentIsHandedOff() throws {
        var library = LibraryCatalog(services: .fake())
        try library.perform([.handOff(path: "/w/Intro.halo", app: "halo")])
        #expect(library.items.isEmpty)
    }
}
