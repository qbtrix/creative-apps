// LargeCatalogBudgetTests.swift: large-catalog's Model budgets (MJ-LG, packet
// docs/blueprints/library/features/large-catalog.md, Contract slice) on the
// 10,000-photo fixture. The fixture's own test gates; LG-3 and LG-4 met the
// load, selection, plan and sheet budgets (LargeCatalogModelBudgetTests), which
// time wall clock and so run from the perf list in perf-nightly.
import Foundation
import SuiteKernel
import Testing

@testable import LibraryModel

@Suite struct LargeCatalogBudgetTests {
    /// A fresh folder for one test's JPEGs.
    static func folder(_ name: String) -> String {
        FileManager.default.temporaryDirectory.appendingPathComponent("large-\(name)-\(UUID().uuidString)").path
    }

    /// LG-1: 10,000 varied photos with their files, the same on a second build.
    /// Its 5 s budget is LargeCatalogFixtureBudgetTests, kept out of the gate.
    @Test func fixtureBuildsTenThousandDeterministically() throws {
        let folder = Self.folder("fixture")
        defer { try? FileManager.default.removeItem(atPath: folder) }
        let first = try LibraryFixtures.large(count: 10_000, folder: folder)
        #expect(first.items.count == 10_000 && first.order.count == 10_000)
        #expect(try LibraryFixtures.large(count: 10_000, folder: folder) == first)
        // Ratings, flags, labels, shapes, dates and folders vary.
        #expect(Set(first.items.map(\.rating)) == Set(0...5))
        #expect(Set(first.items.map(\.flag)).count == 3 && Set(first.items.map(\.label)).count == 6)
        #expect(Set(first.items.map(\.pixelSize)).count == 2)
        #expect(Set(first.items.map(\.captureDate)).count == 10_000)
        let folders = Set(first.items.compactMap { $0.path.map { ($0 as NSString).deletingLastPathComponent } })
        #expect(folders.count >= 20)
        // Photo i and its bytes don't depend on the count or the folder.
        let other = Self.folder("small")
        defer { try? FileManager.default.removeItem(atPath: other) }
        let small = try LibraryFixtures.large(count: 64, folder: other)
        for (a, b) in zip(first.items.prefix(64), small.items) {
            #expect(a.name == b.name && a.rating == b.rating && a.captureDate == b.captureDate && a.color == b.color)
            let bytes = try Data(contentsOf: URL(fileURLWithPath: a.path ?? ""))
            #expect(bytes == (try Data(contentsOf: URL(fileURLWithPath: b.path ?? ""))))
            #expect(bytes.prefix(2) == Data([0xFF, 0xD8]) && bytes.suffix(2) == Data([0xFF, 0xD9]))
        }
    }

    /// The fixture of `count`; its files are removed once it is built.
    static func catalog(_ count: Int, _ name: String) throws -> LibraryCatalog {
        let folder = folder(name)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        return try LibraryFixtures.large(count: count, folder: folder)
    }

    /// Release budgets are on 10,000; a debug build times a tenth so it stays quick.
    #if DEBUG
    static let scale = 10
    #else
    static let scale = 1
    #endif
}

/// MJ-LG's Model budgets, which LG-3 and LG-4 (LG-model) meet. They time wall
/// clock, so the gate never runs them: Tests/perf-suites.txt lists this suite and
/// it runs in perf-nightly.
@Suite
struct LargeCatalogModelBudgetTests {
    typealias Base = LargeCatalogBudgetTests

    @Test func loadWithinBudget() throws {
        let photos = try Base.catalog(10_000 / Base.scale, "load").items
        let cost = Budget.measure("large load-10000", runs: 5) {
            var catalog = LibraryCatalog(services: .fake(photos))
            catalog.load(photos)
        }
        #expect(cost.median <= 400.0 / Double(Base.scale), "load took \(cost.median) ms (median)")
    }

    @Test func selectAllWithinBudget() throws {
        var catalog = try Base.catalog(10_000 / Base.scale, "all")
        let cost = Budget.measure("large select-all-10000", runs: 10) {
            catalog.select([])
            try? catalog.run(.selectAll)
        }
        #expect(catalog.selection.count == catalog.order.count)
        #expect(cost.median <= 5.0 / Double(Base.scale), "select all took \(cost.median) ms (median)")
    }

    @Test func shiftRangeWithinBudget() throws {
        var catalog = try Base.catalog(10_000 / Base.scale, "range")
        let order = catalog.order, span = 5_000 / Base.scale
        guard order.count > span else { Issue.record("the fixture is too small"); return }
        let cost = Budget.measure("large shift-range-5000", runs: 10) {
            catalog.pick(order[0], .replace)
            catalog.pick(order[span - 1], .extend)
        }
        #expect(catalog.selection.count == span)
        #expect(cost.median <= 10.0 / Double(Base.scale), "shift-range took \(cost.median) ms (median)")
    }

    /// Debug budget, at full size: the plan for 1,000 of the fixture's photos.
    @Test func exportPlanWithinBudget() throws {
        let catalog = try Base.catalog(10_000, "plan")
        let photos = Array(catalog.items.prefix(1_000))
        let exporter = LiveExporter(decoder: FakeDecoder(photos: []), develop: FakeDevelop())
        let options = ExportOptions(folder: "/out", naming: ExportNaming(template: "{date}-{seq}"))
        var plan = ExportPlan(items: [], options: options)
        let cost = Budget.measure("large export-plan-1000", runs: 5) {
            plan = exporter.plan(photos, options: options, existingNames: [])
        }
        #expect(Set(plan.items.map(\.fileName)).count == 1_000)
        #expect(cost.median <= 50, "the plan took \(cost.median) ms (median), over 50 ms")
    }

    /// Debug budget, at full size: opening the sheet on 10,000 selected photos.
    @Test func beginExportWithinBudget() throws {
        var catalog = try Base.catalog(10_000, "begin")
        catalog.select(Set(catalog.order))
        let cost = Budget.measure("large export-begin-10000", runs: 5) {
            catalog.closeExport()
            _ = catalog.beginExport(folder: "/out")
        }
        #expect(catalog.exportState == .editing(ExportOptions(folder: "/out")))
        #expect(cost.median <= 10, "beginExport took \(cost.median) ms (median), over 10 ms")
    }
}

/// LG-1's wall-clock budget: the 10,000-photo fixture builds in under 5 s. A
/// timing test never gates CI: Tests/perf-suites.txt lists this suite, so it
/// runs in perf-nightly and the gate skips it.
@Suite struct LargeCatalogFixtureBudgetTests {
    @Test func fixtureBuildsUnderFiveSeconds() throws {
        let folder = LargeCatalogBudgetTests.folder("fixture-budget")
        defer { try? FileManager.default.removeItem(atPath: folder) }
        let start = ContinuousClock.now
        let catalog = try LibraryFixtures.large(count: 10_000, folder: folder)
        let elapsed = ContinuousClock.now - start
        #expect(catalog.items.count == 10_000)
        #expect(elapsed < .seconds(5), "the fixture took \(elapsed), over 5 s")
    }
}
