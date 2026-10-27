// LargeCatalogEquivalenceTests.swift: large-catalog's LG-model (packet
// docs/blueprints/library/features/large-catalog.md, LG-3 and LG-4) keeps
// behavior: selection, select all, shift-range, export names and the sheet's
// "can export" answer equal the old path's on random cases and the fixture.
// No timing here; LargeCatalogBudgetTests holds the budgets.
import Foundation
import SuiteKernel
import SuiteModel
import Testing

@testable import LibraryModel

@Suite struct LargeCatalogEquivalenceTests {
    /// The old naming path: a full UniqueFileNames scan of every name taken so far, per photo.
    static func oldUnique(stems: [String], format: ExportFormat, sidecar: Bool, existing: Set<String>) -> [String] {
        let image = "." + format.fileExtension
        let suffixes = sidecar ? [image, ".xmp"] : [image]
        var taken = Set(existing.compactMap { name in
            suffixes.first { name.lowercased().hasSuffix($0) }.map { String(name.dropLast($0.count)) }
        })
        return stems.map { stem in
            let picked = UniqueFileNames.name(stem, extension: "", among: taken)
            taken.insert(picked)
            return picked + image
        }
    }

    /// The old `exportHelp` test: the targets built in full.
    static func oldHasTarget(_ catalog: LibraryCatalog) -> Bool { !catalog.exportTargets.isEmpty }

    @Test func exportNamesEqualTheOldPathOnRandomStems() {
        var rng = SystemRandomNumberGenerator()
        let pool = ["IMG_0001", "img_0001", "IMG_0001 2", "Card", "card 3", "a/b", "x:y", " ", "", ".hidden", "Ünïcode"]
        for _ in 0..<100 {
            let stems = (0..<Int.random(in: 0...40, using: &rng)).map { _ in pool.randomElement(using: &rng) ?? "" }
            let format = ExportFormat.allCases.randomElement(using: &rng) ?? .jpeg
            let sidecar = Bool.random(using: &rng)
            let existing = Set((0..<Int.random(in: 0...6, using: &rng)).map { _ in
                (pool.randomElement(using: &rng) ?? "") + ([".jpg", ".PNG", ".xmp", ".tif", ".heic", ""].randomElement(using: &rng) ?? "")
            })
            let new = ExportNames.unique(stems: stems, format: format, sidecar: sidecar, existing: existing)
            #expect(new == Self.oldUnique(stems: stems, format: format, sidecar: sidecar, existing: existing),
                    "stems \(stems) among \(existing)")
            #expect(Set(new.map { $0.lowercased() }).count == new.count)
        }
    }

    @Test func thePlanNamesEqualTheOldPlanOnTheFixture() throws {
        let catalog = try LargeCatalogBudgetTests.catalog(400, "names")
        let exporter = LiveExporter(decoder: FakeDecoder(photos: []), develop: FakeDevelop())
        for template in ["{date}-{seq}", "{name}", "{date}", "{rating}-{name}"] {
            let options = ExportOptions(folder: "/out", naming: ExportNaming(template: template))
            let photos = catalog.items
            let plan = exporter.plan(photos, options: options, existingNames: ["IMG_0001.jpg"])
            let stems = photos.enumerated().map { options.naming.stem(for: $1, index: $0, count: photos.count) }
            #expect(options.naming.stems(for: photos) == stems)
            let old = Self.oldUnique(stems: stems, format: options.format, sidecar: options.sidecar, existing: ["IMG_0001.jpg"])
            #expect(plan.items.map(\.fileName) == old, "template \(template)")
            #expect(Set(plan.items.map { $0.fileName.lowercased() }).count == photos.count)
        }
    }

    @Test func selectionEqualsTheOldPathOnRandomCases() throws {
        let base = try LargeCatalogBudgetTests.catalog(300, "select")
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<100 {
            var catalog = base
            if Bool.random(using: &rng) { catalog.setRatingRule(.atLeast(Int.random(in: 1...5, using: &rng))) }
            let all = catalog.items.map(\.id), order = catalog.order
            let ids = Set(all.filter { _ in Int.random(in: 0..<4, using: &rng) == 0 })
            catalog.select(ids)
            #expect(catalog.picks.ordered == order.filter(ids.contains))
            #expect(catalog.selection == ids.intersection(order))
            try catalog.run(.selectAll)
            #expect(catalog.picks.ordered == order && catalog.selection == Set(order))
            guard order.count > 1 else { continue }
            let a = Int.random(in: 0..<order.count, using: &rng), b = Int.random(in: 0..<order.count, using: &rng)
            catalog.pick(order[a], .replace)
            #expect(catalog.pick(order[b], .extend) == (a != b))
            #expect(catalog.selection == Set(order[min(a, b)...max(a, b)]))
        }
    }

    @Test func canExportEqualsTheOldPathOnRandomCases() throws {
        let base = try LargeCatalogBudgetTests.catalog(200, "begin")
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<100 {
            var catalog = base
            if Bool.random(using: &rng) { catalog.setRatingRule(.exactly(Int.random(in: 0...5, using: &rng))) }
            let all = catalog.items.map(\.id)
            catalog.selection = Set(all.filter { _ in Int.random(in: 0..<50, using: &rng) == 0 } + ["missing"])
            #expect(catalog.hasExportTarget == Self.oldHasTarget(catalog))
            #expect((catalog.exportHelp == nil) == (catalog.beginExport(folder: "/out")))
            catalog.closeExport()
        }
    }
}
