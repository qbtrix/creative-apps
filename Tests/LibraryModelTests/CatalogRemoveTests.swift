// CatalogRemoveTests.swift (catalog-files LC-1 written, LC-6 on): Remove from Catalog keeps the files and is one
// undo step that restores ratings and develop. `specsAreStubs` pins the LC-1 stubs. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct CatalogRemoveTests {
    /// Ten photos backed by real files in a fresh temp folder; the first three rated 3 and brightened.
    static func shoot() throws -> [PhotoItem] {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CatalogRemoveTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try (1...10).map { n in
            let name = "IMG_000\(n - 1)"
            let file = folder.appendingPathComponent(name + ".jpg")
            try Data("photo \(n)".utf8).write(to: file)
            var photo = PhotoItem(id: file.path, name: name, captureDate: Date(timeIntervalSince1970: Double(n) * 60),
                                  color: Color3(0.5, 0.5, 0.5), path: file.path)
            if n <= 3 { photo.rating = 3; photo.develop = DevelopSettings.neutral.setting(.exposure, to: 0.5) }
            return photo
        }
    }

    @Test(.disabled("waits on LC-6")) func removeKeepsFilesAndIsOneUndoStep() throws {
        let photos = try Self.shoot()
        var library = LibraryCatalog()
        library.load(photos)
        library.select(Set(photos.prefix(3).map(\.id)))
        _ = try LibraryCatalog.catalog.run("photo.remove-from-catalog", params: .object([:]), on: &library)
        #expect(library.items.map(\.id) == photos.dropFirst(3).map(\.id))
        for photo in photos { #expect(FileManager.default.fileExists(atPath: photo.path ?? "")) }
        #expect(library.undoTitle == "Undo Remove from Catalog")
        library.undo()
        #expect(library.items == photos)
    }

    @Test(.disabled("waits on LC-6")) func removingKeepsTheRestInOrder() {
        let photos = LibraryFixtures.shoot()
        let kept = CatalogFileRules.removing([photos[0].id, photos[5].id], from: photos)
        #expect(kept.map(\.id) == photos.enumerated().filter { $0.offset != 0 && $0.offset != 5 }.map(\.element.id))
    }

    /// On now: both commands are declared, off with the reason, refuse to run, and are not yet in the catalog.
    @Test func specsAreStubs() throws {
        #expect(LibraryCatalog.catalogFileSpecs.map(\.id) == ["photo.remove-from-catalog", "photo.relink"])
        let commands = try CommandCatalog(app: "library", LibraryCatalog.catalogFileSpecs,
                                          history: { LibraryCatalogSteps(catalog: $0) })
        var library = LibraryCatalog()
        let why = LibraryCatalog.catalogFilesHelp
        #expect(throws: CatalogError.unavailable(id: "photo.remove-from-catalog", why: why)) {
            try commands.run("photo.remove-from-catalog", params: .object([:]), on: &library)
        }
        #expect(throws: CatalogError.unavailable(id: "photo.relink", why: why)) {
            try commands.run("photo.relink", params: .object(["id": .string("a"), "file": .string("/b.jpg")]), on: &library)
        }
        #expect(!LibraryCatalog.catalog.ids.contains("photo.remove-from-catalog"))
        #expect(!LibraryCatalog.catalog.ids.contains("photo.relink"))
        let photos = LibraryFixtures.shoot()
        #expect(CatalogFileRules.removing(Set(photos.map(\.id)), from: photos) == photos)
        #expect(CatalogFileRules.relinks(missing: photos, located: (id: "IMG_0001", file: "/moved/IMG_0001.jpg"),
                                         size: { _ in 1 }).isEmpty)
    }
}
