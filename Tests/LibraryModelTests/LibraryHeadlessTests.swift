// LibraryHeadlessTests.swift (adopt-command-catalog AC-l3): LibraryHeadless opens a `.library` file (a catalog plus
// its images), imports images the catalog doesn't list, saves and reopens to the same photos, and exports the picks
// only. Tests/RealJobs/library's jobs run here through `LibraryJob`: the export's files and sizes always, and the
// pixels once core's PNG decodes (qbtrix/creative-core#562). Linux-safe.
import CoreRaster
import Foundation
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct LibraryHeadlessTests {
    static func input(_ job: String) throws -> Data {
        try Data(contentsOf: LibraryJob.root.appendingPathComponent("\(job)/input/shoot.library"))
    }

    @Test func openSaveReopenIsTheSameDocument() throws {
        var doc = try LibraryHeadless.open(Self.input("cull-and-save"), name: "shoot.library")
        #expect(doc.library.items.map(\.id) == ["beach", "dock", "fog", "pier"])
        _ = try LibraryHeadless.catalog.run("edit.select", params: .object(["ids": .array([.string("fog")])]), on: &doc)
        _ = try LibraryHeadless.catalog.run("metadata.set-rating", params: .object(["stars": .number(3)]), on: &doc)
        try doc.importImage(#require(doc.images["images/dock.png"]), name: "copy.png")
        let reopened = try LibraryHeadless.open(doc.save(), name: "shoot.library")
        #expect(reopened.library.items == doc.library.items)
        #expect(reopened.images == doc.images)
        #expect(reopened.library.items.last?.path == "images/copy.png")
        #expect(try reopened.save() == doc.save())
        #expect(throws: CatalogError.self) { try LibraryHeadless.open(Data("not a zip".utf8), name: "x.library") }
    }

    @Test func openImportsTheImagesTheCatalogDoesNotList() throws {
        let doc = try LibraryHeadless.open(Self.input("import-rate-export"), name: "shoot.library")
        #expect(doc.library.items.map(\.id) == ["dunes", "harbor", "meadow", "tower"])
        #expect(doc.library.items.map { [$0.pixelSize.width, $0.pixelSize.height] }
            == [[1600, 900], [1280, 960], [1200, 1200], [960, 1280]])
        #expect(doc.library.saveRevision == doc.library.savedRevision)
    }

    @Test func exportIsOfThePicksOnly() throws {
        var doc = try LibraryHeadless.open(Self.input("import-rate-export"), name: "shoot.library")
        #expect(throws: CatalogError.self) { try doc.export("png", options: .object([:])) } // no picks yet
        _ = try LibraryHeadless.catalog.run("edit.select", params: .object(["ids": .array([.string("meadow")])]), on: &doc)
        _ = try LibraryHeadless.catalog.run("metadata.pick", params: .object([:]), on: &doc)
        let plan = doc.exportPlan(longSide: 600)
        #expect(plan.items.map(\.fileName) == ["meadow.png"])
        #expect(plan.items.map { [$0.size.width, $0.size.height] } == [[600, 600]])
        #expect(doc.exportPlan(longSide: nil).items.map(\.size) == [PixelSize(width: 1200, height: 1200)])
        let json = try #require(doc.export("json", options: .object([:])).first)
        #expect(json.suggestedName == "shoot.json")
        #expect(try ZipStore.entries(doc.save())["catalog.json"] == json.data)
        #expect(throws: CatalogError.self) { try doc.export("tiff", options: .object([:])) }
    }

    @Test func newAndSummary() throws {
        let doc = try LibraryHeadless.new(.object([:]))
        #expect(doc.library.items.isEmpty && doc.images.isEmpty)
        #expect(doc.summary() == .object(["app": .string("library"), "photos": .array([])]))
        let shoot = try LibraryHeadless.open(Self.input("cull-and-save"), name: "shoot.library")
        guard case .object(let s) = shoot.summary(), case .array(let photos)? = s["photos"] else {
            Issue.record("no photos"); return
        }
        #expect(photos.first == .object(["id": .string("beach"), "name": .string("beach"), "rating": .number(0),
                                         "flag": .string("None"), "label": .null]))
        #expect(LibraryHeadless.catalog.ids == LibraryCatalog.catalog.ids)
        #expect(LibraryHeadless.catalog.availability("file.load-samples", on: shoot) == .unavailable(LibraryHeadless.fileCommandHelp))
    }

    @Test(arguments: ["cull-and-save", "import-rate-export"])
    func realJobPasses(job: String) throws {
        #expect(try LibraryJob.check(job) == [], "\(job)")
    }
}

/// Runs a `Tests/RealJobs/library/<job>/` script on LibraryHeadless and checks its `expect` block. Unlike the CLI it
/// runs a job whose `pending` names a CLI gap, and a multi-file export lands at `out/<name>/<file>`, Design's layout.
/// A png output must be exactly the expected files at each reference's size; pixels wait on core's PNG.
enum LibraryJob {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("RealJobs/library")
    struct Script: Decodable { var steps: [CommandEnvelope], atomic: Bool, output: Output, expect: [String: JSONValue] }
    struct Output: Decodable { var name: String; var format: String; var options: JSONValue }
    struct Pixels: Decodable { var tolerance: Int; var reference: String }

    /// Every expectation of `job` that failed, in words; empty when the job passes.
    static func check(_ job: String) throws -> [String] {
        let folder = root.appendingPathComponent(job)
        let script = try JSONDecoder().decode(Script.self, from: Data(contentsOf: folder.appendingPathComponent("\(job).jobs.json")))
        let inputs = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("input").path)
            .filter { $0.hasSuffix(".library") }.sorted()
        var failures: [String] = [], written: Set<String> = []
        for name in inputs {
            var doc = try LibraryHeadless.open(Data(contentsOf: folder.appendingPathComponent("input/\(name)")), name: name)
            let report = LibraryHeadless.catalog.runBatch(script.steps, on: &doc, atomic: script.atomic)
            guard report.stoppedAt == nil else { return ["\(name): \(report.steps.compactMap(\.error))"] }
            let o = script.output, out = "out/" + o.name.replacingOccurrences(of: "{stem}", with: String(name.dropLast(".library".count)))
            if o.format == "json" {
                written.insert("\(out).json")
                let saved = try ZipStore.entries(doc.save())["catalog.json"]
                for data in try [doc.export("json", options: o.options).first?.data, saved] {
                    let got = try data.map { try JSONValue(json: $0) }
                    if got != script.expect["\(out).json"].flatMap(json) { failures.append("\(out).json: JSON differs") }
                }
                continue
            }
            let longSide = if case .object(let f) = o.options, case .number(let n)? = f["longSide"] { Int(n) } else { Int?.none }
            let plan = doc.exportPlan(longSide: longSide).items
            let files = try? doc.export(o.format, options: o.options) // nil while core's PNG can't read or write
            for (index, item) in plan.enumerated() {
                let path = "\(out)/\(item.fileName)"
                written.insert(path)
                guard case .object(let kind)? = script.expect[path] else { continue }
                let pixels = try (kind["pixels"] ?? .null).decode(Pixels.self)
                let reference = try Data(contentsOf: folder.appendingPathComponent(pixels.reference))
                guard let want = LibraryHeadless.pngSize(reference), want == item.size else {
                    failures.append("\(path): planned \(item.size), the reference is \(LibraryHeadless.pngSize(reference).map { "\($0)" } ?? "unreadable")")
                    continue
                }
                guard let files, files.indices.contains(index) else { continue }
                let got = try PNG.read(files[index].data).rgba8(), ref = try PNG.read(reference).rgba8()
                let worst = got.count == ref.count ? zip(got, ref).map { abs(Int($0) - Int($1)) }.max() ?? 0 : Int.max
                if worst > pixels.tolerance { failures.append("\(path): a channel is off by \(worst)") }
            }
        }
        failures += Set(script.expect.keys).symmetricDifference(written).sorted().map { "\($0): written but not expected, or the reverse" }
        return failures
    }

    static func json(_ want: JSONValue) -> JSONValue? {
        if case .object(let kind) = want { kind["json"] } else { nil }
    }
}
