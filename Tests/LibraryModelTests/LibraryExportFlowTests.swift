// LibraryExportFlowTests.swift: EX-3, the catalog's export states and the
// runner, with MX1 (the Model walk).
import Foundation
import Testing

@testable import LibraryModel

/// Fails `render` for one photo id; every other photo renders on the fake.
private struct FailingExporter: PhotoExporting {
    let failing: String
    func plan(_ photos: [PhotoItem], options: ExportOptions, existingNames: Set<String>) -> ExportPlan {
        FakeExporter().plan(photos, options: options, existingNames: existingNames)
    }
    func render(_ item: ExportPlan.Item, photo: PhotoItem) async throws -> DisplayImage {
        if photo.id == failing { throw LibraryError.renderFailed("broken on purpose") }
        return try await FakeExporter().render(item, photo: photo)
    }
}

/// Collects the runner's progress reports in order.
private final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var reports: [Int] = []
    func add(_ done: Int) { lock.lock(); reports.append(done); lock.unlock() }
    var all: [Int] { lock.lock(); defer { lock.unlock() }; return reports }
}

@Suite struct LibraryExportFlowTests {
    func shoot(selecting names: [String]) -> LibraryCatalog {
        let photos = LibraryFixtures.photos(named: "shoot")
        var catalog = LibraryCatalog(services: .fake(photos))
        catalog.load(photos)
        catalog.setSort(.name)
        catalog.select(Set(names.map { "/fixture/shoot/\($0).jpg" }))
        return catalog
    }

    func id(_ name: String) -> String { "/fixture/shoot/\(name).jpg" }

    @Test func gridTargetsTheSelectionInOrderAndLoupeItsPhoto() {
        var catalog = shoot(selecting: ["IMG_0003", "IMG_0001"])
        #expect(catalog.exportTargets.map(\.name) == ["IMG_0001", "IMG_0003"])
        catalog.open(id("IMG_0005"))
        #expect(catalog.exportTargets.map(\.name) == ["IMG_0005"])
    }

    @Test func noTargetsRefusesWithHelp() {
        var catalog = shoot(selecting: [])
        #expect(catalog.exportHelp == "Select a photo to export it.")
        #expect(catalog.beginExport(folder: "/out") == false)
        #expect(catalog.exportState == .idle)
    }

    @Test func runningRefusesASecondExportAndClose() {
        var catalog = shoot(selecting: ["IMG_0001"])
        #expect(catalog.exportHelp == nil)
        #expect(catalog.beginExport(folder: "/out") == true)
        let history = catalog.history
        #expect(catalog.exportPlan(existingNames: [])?.items.count == 1)
        #expect(catalog.exportState == .running(done: 0, total: 1))
        #expect(catalog.exportHelp == "An export is already running.")
        #expect(catalog.beginExport(folder: "/other") == false)
        catalog.setExportOptions(ExportOptions(longEdge: 512, folder: "/out"))
        #expect(catalog.exportState == .running(done: 0, total: 1))
        catalog.closeExport()
        #expect(catalog.exportState == .running(done: 0, total: 1))
        catalog.showExportProgress(done: 1, total: 1)
        #expect(catalog.exportState == .running(done: 1, total: 1))
        catalog.finishExport(ExportSummary(total: 1, written: ["IMG_0001.jpg"]))
        #expect(catalog.history == history)
        catalog.closeExport()
        #expect(catalog.exportState == .idle)
    }

    @Test func optionsChangeOnlyWhileEditing() {
        var catalog = shoot(selecting: ["IMG_0001"])
        catalog.setExportOptions(ExportOptions(longEdge: 512, folder: "/out"))
        #expect(catalog.exportState == .idle)
        #expect(catalog.beginExport(folder: "/out") == true)
        #expect(catalog.exportState == .editing(ExportOptions(folder: "/out")))
        catalog.setExportOptions(ExportOptions(longEdge: 512, folder: "/out"))
        #expect(catalog.exportState == .editing(ExportOptions(longEdge: 512, folder: "/out")))
    }

    @Test func previewReadsNameAndSize() {
        var catalog = shoot(selecting: ["IMG_0001"])
        #expect(catalog.beginExport(folder: "/out") == true)
        #expect(catalog.exportPreview == "IMG_0001.jpg · 2048 × 1365")
    }

    @Test func aFailureKeepsGoingAndIsListedWithItsID() async throws {
        let photos = LibraryFixtures.photos(named: "shoot").prefix(3)
        let byID = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
        let options = ExportOptions(longEdge: 256, folder: "/out")
        let exporter = FailingExporter(failing: id("IMG_0002"))
        let plan = exporter.plan(Array(photos), options: options, existingNames: [])
        let writer = FakeJPEGWriter()
        let log = ProgressLog()
        let summary = await ExportRunner.run(plan, photos: byID, exporter: exporter, writer: writer,
                                             writeSidecar: { _, _, _ in }, progress: { log.add($0) })
        #expect(summary.written == ["IMG_0001.jpg", "IMG_0003.jpg"])
        #expect(summary.failures == [FileFailure(path: "IMG_0002.jpg",
                                                 reason: "Couldn't render this photo: broken on purpose.")])
        #expect(summary.failedIDs == [id("IMG_0002")])
        #expect(summary.total == 3)
        #expect(log.all == [1, 2, 3])
        #expect(try await writer.existingNames(in: "/out") == ["IMG_0001.jpg", "IMG_0003.jpg"])
    }

    @Test func testExportWalk() async throws {
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
            let log = ProgressLog()
            let summary = await ExportRunner.run(plan, photos: photos, exporter: FakeExporter(), writer: writer,
                                                 writeSidecar: { _, _, _ in }, progress: { log.add($0) })
            #expect(log.all == [1, 2])
            for done in log.all { catalog.showExportProgress(done: done, total: plan.items.count) }
            #expect(catalog.exportState == .running(done: 2, total: 2))
            catalog.finishExport(summary)
            #expect(summary.message == "Exported 2 photos.")
            #expect(catalog.exportState == .finished(summary))
            catalog.closeExport()
            #expect(catalog.exportState == .idle)
        }
    }
}
