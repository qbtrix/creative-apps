// LibraryExportBudgetTests.swift: EX-12, QB-L9's and QB-LIB-7's model halves
// (packet docs/blueprints/library/features/export.md, Budgets), timed on EX-2's
// and EX-3's real code: begin within 10 ms and plan within 50 ms in a debug
// build, 1 ms and 5 ms optimized (#3213 and #3214 fixed the misses). They sit
// in the develop budget suite, which the perf list runs nightly on the Mac, so
// a busy CI runner never judges them.
import Foundation
import Testing

@testable import LibraryModel

/// The packet's limit: `debug` ms in a debug build, a tenth of it optimized.
private func exportLimit(_ debug: Double) -> Double { _isDebugAssertConfiguration() ? debug : debug / 10 }

extension LibraryDevelopBudgetTests {
    /// QB-L9 model half: opening the sheet on 10,000 selected photos.
    @Test func beginExportWithinBudget() {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "large"))
        catalog.select(Set(catalog.items.map(\.id)))
        #expect(catalog.order.count == 10_000)
        #expect(catalog.exportTargets.count == 10_000)
        let cost = Budget.measure("export begin-10000") { _ = catalog.beginExport(folder: "/out") }
        #expect(catalog.exportState == .editing(ExportOptions(folder: "/out")))
        #expect(cost.median <= exportLimit(10), "beginExport on 10,000 took \(cost.median) ms (median), over \(exportLimit(10)) ms")
    }

    /// QB-LIB-7 model half: the live plan for 1,000 photos under `{date}-{seq}`
    /// with sidecars, against a folder that already holds some of its names.
    @Test func planWithinBudget() {
        let photos = Array(LibraryFixtures.photos(named: "large").prefix(1_000))
        #expect(photos.count == 1_000)
        let exporter = LiveExporter(decoder: FakeDecoder(photos: []), develop: FakeDevelop())
        let options = ExportOptions(longEdge: 2048, folder: "/out",
                                    naming: ExportNaming(template: "{date}-{seq}"), sidecar: true)
        #expect(options.naming.help == nil)
        let existing = Set(exporter.plan(Array(photos.prefix(50)), options: options, existingNames: [])
            .items.map(\.fileName))
        var plan = ExportPlan(items: [], options: options)
        let cost = Budget.measure("export plan-1000") {
            plan = exporter.plan(photos, options: options, existingNames: existing)
        }
        #expect(plan.items.count == 1_000)
        #expect(Set(plan.items.map(\.fileName)).count == 1_000)
        #expect(plan.items.allSatisfy { max($0.size.width, $0.size.height) <= 2048 })
        #expect(cost.median <= exportLimit(50), "LiveExporter.plan for 1,000 took \(cost.median) ms (median), over \(exportLimit(50)) ms")
    }
}
