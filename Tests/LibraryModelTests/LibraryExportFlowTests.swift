// LibraryExportFlowTests.swift: EX-3, the catalog's export states and the
// runner, with MX1 (the Model walk). Written by EX-1, disabled until EX-3.
import Foundation
import Testing

@testable import LibraryModel

@Suite struct LibraryExportFlowTests {
    func shoot(selecting names: [String]) -> LibraryCatalog {
        let photos = LibraryFixtures.photos(named: "shoot")
        var catalog = LibraryCatalog(services: .fake(photos))
        catalog.load(photos)
        catalog.setSort(.name)
        catalog.select(Set(names.map { "/fixture/shoot/\($0).jpg" }))
        return catalog
    }

    @Test(.disabled("waits on EX-3")) func previewReadsNameAndSize() {
        var catalog = shoot(selecting: ["IMG_0001"])
        #expect(catalog.beginExport(folder: "/out") == true)
        #expect(catalog.exportPreview == "IMG_0001.jpg · 2048 × 1365")
    }

    @Test(.disabled("waits on EX-3")) func testExportWalk() async throws {
        var catalog = shoot(selecting: ["IMG_0002", "IMG_0001"])
        let writer = FakeJPEGWriter()
        for round in ["", " 2"] {
            #expect(catalog.beginExport(folder: "/out") == true)
            catalog.setExportOptions(ExportOptions(longEdge: 1024, quality: 80, folder: "/out"))
            let planned = catalog.exportPlan(existingNames: try await writer.existingNames(in: "/out"))
            let plan = try #require(planned)
            #expect(plan.items.map(\.fileName) == ["IMG_0001\(round).jpg", "IMG_0002\(round).jpg"])
            #expect(plan.items.first?.size == PixelSize(width: 1024, height: 683))
            let photos = Dictionary(uniqueKeysWithValues: catalog.exportTargets.map { ($0.id, $0) })
            let summary = await ExportRunner.run(plan, photos: photos, exporter: FakeExporter(), writer: writer,
                                                 writeSidecar: { _, _, _ in }, progress: { _ in })
            catalog.finishExport(summary)
            #expect(summary.message == "Exported 2 photos.")
            catalog.closeExport()
            #expect(catalog.exportState == .idle)
        }
    }
}
