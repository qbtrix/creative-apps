// LibraryLiveSidecarsTests.swift: the window's live launch writes XMP sidecars (#5198). A launch
// with no fixture gives the catalog `XMPSidecarWriter`, and a rating on a photo with a file lands in
// an `.xmp` beside it on a real folder, through the window's services and through the sidecar
// area's write step. macOS only.
#if os(macOS)
import CoreColor
import Foundation
import LibraryModel
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryLiveSidecarsTests {
    /// A fresh folder holding a stand-in `IMG_1.jpg`; removed afterwards.
    private func inFolder(_ body: (URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "LibraryLiveSidecars-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: root.appending(path: "IMG_1.jpg"))
        try await body(root)
    }

    /// The live window's catalog over one photo at `root/IMG_1.jpg`, rated 3 stars.
    private func ratedCatalog(in root: URL) throws -> LibraryCatalog {
        let path = root.appending(path: "IMG_1.jpg").path
        var catalog = LibraryCatalog(services: LibraryWindow(arguments: ["Library"]).model.services)
        catalog.load([PhotoItem(id: path, name: "IMG_1", captureDate: Date(), color: Color3(0.5, 0.5, 0.5),
                                path: path)])
        catalog.select([path])
        try catalog.run(.setRating(3))
        return catalog
    }

    @Test func liveWindowRatingWritesASidecar() async throws {
        try await inFolder { root in
            let catalog = try ratedCatalog(in: root)
            #expect(catalog.services.sidecars is XMPSidecarWriter)
            #expect(catalog.services.unavailable["sidecars"] == nil)
            let plan = catalog.sidecarWrites(after: [:])
            #expect(plan.count == 1)
            for write in plan { try await catalog.services.sidecars.write(write.data, sidecar: write.path) }
            let xmp = try Data(contentsOf: root.appending(path: "IMG_1.xmp"))
            #expect(XMPSidecar.isWrittenByLibrary(xmp))
            #expect(String(decoding: xmp, as: UTF8.self).contains("xmp:Rating"))
        }
    }

    @Test func theSidecarAreaWritesThePlanAndReportsEachPhoto() async throws {
        try await inFolder { root in
            let catalog = try ratedCatalog(in: root)
            let plan = catalog.sidecarWrites(after: [:])
            let results = await LibraryWindow.writeSidecars(plan, with: catalog.services.sidecars)
            #expect(results.map(\.write) == plan && results.allSatisfy { $0.failure == nil })
            #expect(XMPSidecar.isWrittenByLibrary(try Data(contentsOf: root.appending(path: "IMG_1.xmp"))))
            // Another app's sidecar is left alone, with the writer's sentence.
            try Data("<x:xmpmeta/>".utf8).write(to: root.appending(path: "IMG_1.xmp"))
            let foreign = await LibraryWindow.writeSidecars(plan, with: catalog.services.sidecars)
            #expect(foreign.first?.failure?.contains("written by another app") == true)
        }
    }
}
#endif
