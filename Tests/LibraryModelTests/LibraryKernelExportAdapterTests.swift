// LibraryKernelExportAdapterTests.swift: the catalog's export sheet runs on
// SuiteKernel's `ExportRun<ExportOptions>` (adopt-kernel-export AX-library).
// Each move is one kernel call: open is `begin`, the plan is `start`, progress
// is `progressed`, the summary is `end`, close is `dismiss`. The kernel's
// `finished` holds the written names; the full `ExportSummary` rides beside it,
// and `exportState` is the sheet's readout of both. A move the kernel refuses
// changes nothing. Plan: Tests/mutations/LibraryModel.KernelExportAdapter.json.
// Runs on Linux and macOS.
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct LibraryKernelExportAdapterTests {
    static func shoot(selecting names: [String]) -> LibraryCatalog {
        let photos = LibraryFixtures.photos(named: "shoot")
        var catalog = LibraryCatalog(services: .fake(photos))
        catalog.load(photos)
        catalog.setSort(.name)
        catalog.select(Set(names.map(id)))
        return catalog
    }

    static func id(_ name: String) -> String { "/fixture/shoot/\(name).jpg" }

    @Test func eachMoveIsOneKernelMove() {
        var catalog = Self.shoot(selecting: ["IMG_0001", "IMG_0002"])
        let options = ExportOptions(folder: "/out")
        #expect(catalog.exportRun == .idle)
        #expect(catalog.beginExport(folder: "/out") == true)
        #expect(catalog.exportRun == .editing(options))
        #expect(catalog.exportPlan(existingNames: [])?.items.count == 2)
        #expect(catalog.exportRun == .running(options, done: 0, total: 2))
        catalog.showExportProgress(done: 1, total: 2)
        catalog.showExportProgress(done: 0, total: 2)
        #expect(catalog.exportRun == .running(options, done: 1, total: 2))
        let summary = ExportSummary(total: 2, written: ["IMG_0001.jpg"], failures: [FileFailure(path: "IMG_0002.jpg",
            reason: "full")], failedIDs: [Self.id("IMG_0002")])
        catalog.finishExport(summary)
        #expect(catalog.exportRun == .finished(options, ["IMG_0001.jpg"]))
        #expect(catalog.exportState == .finished(summary))
        catalog.closeExport()
        #expect(catalog.exportRun == .idle)
    }

    @Test func retryReopensAndStartsTheKernelRun() throws {
        var catalog = Self.shoot(selecting: ["IMG_0001", "IMG_0002"])
        #expect(catalog.beginExport(folder: "/out") == true)
        _ = catalog.exportPlan(existingNames: [])
        catalog.finishExport(ExportSummary(total: 2, written: ["IMG_0001.jpg"], failedIDs: [Self.id("IMG_0002")]))
        let options = ExportOptions(longEdge: 512, folder: "/again")
        let retried = catalog.retryExport(options: options, existingNames: [])
        let retry = try #require(retried)
        #expect(retry.items.map(\.photoID) == [Self.id("IMG_0002")])
        #expect(catalog.exportRun == .running(options, done: 0, total: 1))
    }

    @Test func refusedMovesChangeNothing() {
        var catalog = Self.shoot(selecting: ["IMG_0001"])
        catalog.finishExport(ExportSummary(total: 1, written: ["IMG_0001.jpg"]))
        catalog.showExportProgress(done: 1, total: 1)
        #expect(catalog.exportRun == .idle && catalog.exportSummary == nil)
        #expect(catalog.beginExport(folder: "/out") == true)
        _ = catalog.exportPlan(existingNames: [])
        catalog.closeExport()
        catalog.setExportOptions(ExportOptions(longEdge: 512, folder: "/out"))
        #expect(catalog.exportRun == .running(ExportOptions(folder: "/out"), done: 0, total: 1))
    }

    @Test func theReadoutFollowsTheKernel() {
        let options = ExportOptions(folder: "/out")
        #expect(ExportState(.idle, summary: nil) == .idle)
        #expect(ExportState(.editing(options), summary: nil) == .editing(options))
        #expect(ExportState(.running(options, done: 1, total: 3), summary: nil) == .running(done: 1, total: 3))
        #expect(ExportState(.finished(options, ["a.jpg"]), summary: nil)
            == .finished(ExportSummary(total: 1, written: ["a.jpg"])))
        #expect(ExportState(.failed(options, "The disk is full."), summary: nil)
            == .finished(ExportSummary(total: 0, written: [], failures: [FileFailure(path: "/out",
                reason: "The disk is full.")])))
    }

    @Test func aWrittenStateLandsOnTheKernel() {
        var catalog = LibraryCatalog()
        catalog.exportState = .running(done: 0, total: 1)
        #expect(catalog.exportRun == .running(ExportOptions(folder: ""), done: 0, total: 1))
        #expect(catalog.exportState == .running(done: 0, total: 1))
        #expect(catalog != LibraryCatalog())
    }
}
