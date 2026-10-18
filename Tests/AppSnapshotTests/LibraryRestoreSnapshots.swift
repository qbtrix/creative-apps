// LibraryRestoreSnapshots.swift: the persist area's launch read (persist
// PE-5). A culled catalog of sample photos, each with a file in a temporary
// folder but one, is written as `catalog.json` through CatalogStore and
// LiveCatalogCoding; the window's own read (`readCatalog`) and
// `applyLaunch` restore it into a fresh catalog: the same photos and cull
// state, saved, and the photo whose file is gone `unreadable`. Also: no
// file keeps the catalog's photos, a damaged file is set aside. Writes
// library-restored-{light,dark}.png. macOS only.
import Foundation
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryRestoreSnapshots {
    @Test func restored() async throws {
        let folder = try Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let photos = LibrarySample.items(seed: LibrarySample.defaultSeed).prefix(12).map { sample in
            let path = folder.appendingPathComponent(sample.name + ".jpg").path
            return PhotoItem(
                id: path, name: sample.name, captureDate: sample.captureDate, color: sample.color, path: path,
                pixelSize: sample.pixelSize)
        }
        try #require(photos.count == 12)
        let missingID = photos[2].id
        for photo in photos where photo.id != missingID {
            #expect(FileManager.default.createFile(atPath: photo.id, contents: Data("jpeg".utf8)))
        }

        var catalog = LibraryCatalog()
        catalog.load(photos)
        let order = catalog.sortedItems.map(\.id)
        catalog.select([order[0]])
        catalog.cull(.rating(4))
        catalog.select([order[1]])
        catalog.cull(.flag(.pick))
        catalog.select([order[2]])
        catalog.cull(.label(.red))
        let store = CatalogStore(directory: folder.path)
        try store.writeNow(LiveCatalogCoding().encode(catalog.items))

        var restored = LibraryCatalog()
        restored.beginRestore()
        #expect(restored.catalogState == .loading)
        let result = await LibraryWindow.readCatalog(store: store, coding: LiveCatalogCoding())
        restored.applyLaunch(result)
        #expect(restored.catalogState == .ready)
        #expect(restored.catalogValue == "saved")
        #expect(restored.items.count == 12)
        #expect(restored.sortedItems.map(\.id) == order)
        #expect(restored.cellValue(for: order[0]).contains("4 stars"))
        #expect(restored.cellValue(for: order[1]).contains("Picked"))
        #expect(restored.cellValue(for: order[2]).contains("Red"))
        #expect(restored.cellValue(for: missingID).hasPrefix("unreadable"))
        #expect(restored.cellHelp(for: missingID) == "The file is missing.")
        #expect(restored.items.filter { $0.availability == .missing }.map(\.id) == [missingID])

        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                LibraryBrowser(model: restored).frame(width: 1440, height: 900, alignment: .top),
                name: "library-restored-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func noFileKeepsThePhotosAndADamagedFileIsSetAside() async throws {
        let folder = try Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = CatalogStore(directory: folder.path)
        var empty = LibraryCatalog()
        empty.loadSamples()
        let count = empty.items.count
        empty.beginRestore()
        empty.applyLaunch(await LibraryWindow.readCatalog(store: store, coding: LiveCatalogCoding()))
        #expect(empty.catalogState == .ready && empty.items.count == count)

        try store.writeNow(Data("not json".utf8))
        var damaged = LibraryCatalog()
        damaged.beginRestore()
        damaged.applyLaunch(await LibraryWindow.readCatalog(store: store, coding: LiveCatalogCoding()))
        #expect(damaged.catalogState == .damaged)
        #expect(FileManager.default.fileExists(atPath: store.setAsideURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))

        try store.writeNow(Data(#"{"version": 2}"#.utf8))
        var newer = LibraryCatalog()
        newer.beginRestore()
        newer.applyLaunch(await LibraryWindow.readCatalog(store: store, coding: LiveCatalogCoding()))
        #expect(newer.catalogState == .newer(version: 2))
        #expect(newer.saveRequest() == nil)
        #expect(try Data(contentsOf: store.fileURL) == Data(#"{"version": 2}"#.utf8))
    }

    private static func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibraryRestore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
