// HaloHeadlessTests.swift (adopt-command-catalog AC-h2): HaloHeadless opens, saves, makes, summarizes, lifts
// HaloProject's catalog and renders a frame; Tests/RealJobs/halo's two jobs run here through `HaloJob` until the
// CLI's RealJobs harness (CL-9) runs them, and a pixel job compares against its reference PNG within its tolerance.
import CoreRaster
import Foundation
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloHeadlessTests {
    static func input(_ job: String, _ name: String) throws -> Data {
        try Data(contentsOf: HaloJob.root.appendingPathComponent("\(job)/input/\(name)"))
    }

    @Test func opensAndSavesTheSameBytes() throws {
        let data = try Self.input("retitle-and-save", "card.halo")
        let doc = try HaloHeadless.open(data, name: "card.halo")
        #expect(try doc.save() == data)
        #expect(doc.workspace.compositions.map(\.name) == ["Card"])
        #expect(doc.workspace.file.name == "card.halo")
        #expect(throws: HaloFileError.notAHaloFile) { try HaloHeadless.open(Data("{}".utf8), name: "x.halo") }
    }

    @Test func newMakesOneCompositionFromItsOptions() throws {
        let doc = try HaloHeadless.new(.object(["name": .string("Loop"), "width": .number(320), "height": .number(180), "fps": .number(24), "seconds": .number(2)]))
        let comp = try #require(doc.workspace.selectedComposition)
        #expect([comp.name, "\(comp.width)x\(comp.height)", "\(comp.framesPerSecond)", "\(comp.durationFrames)"] == ["Loop", "320x180", "24", "48"])
        #expect(doc.workspace.history.undo.isEmpty)
        #expect(throws: CatalogError.self) { try HaloHeadless.new(.object(["width": .number(0)])) }
    }

    @Test func summaryNamesTheFileCompositionsSelectionAndPlayhead() throws {
        var doc = try HaloHeadless.open(Self.input("render-frame", "shapes.halo"), name: "shapes.halo")
        _ = try HaloHeadless.catalog.run("timeline.scrub", params: .object(["frame": .number(5)]), on: &doc)
        let comp: JSONValue = .object(["id": .string("comp-1"), "name": .string("Shapes"), "width": .number(64), "height": .number(36),
                                       "fps": .number(24), "frames": .number(24), "layers": .number(2)])
        #expect(doc.summary() == .object(["app": .string("halo"), "name": .string("shapes.halo"), "compositions": .array([comp]),
                                          "selectedComposition": .string("comp-1"), "selectedLayer": .null, "playhead": .number(5)]))
    }

    @Test func theCatalogIsHaloProjectsWithFileCommandsLeftToTheCLI() throws {
        #expect(HaloHeadless.catalog.ids == HaloProject.catalog.ids)
        let doc = HaloHeadless(workspace: commandProject("keyed", .fake))
        for spec in HaloProject.commandSpecs {
            let expected = spec.kind == .file ? .unavailable(HaloHeadless.fileCommandHelp) : spec.availability(doc.workspace)
            #expect(HaloHeadless.catalog.availability(spec.id, on: doc) == expected, "\(spec.id)")
        }
        let key = { (p: String) in p.split(separator: ":").prefix(2).joined(separator: ":") }
        var project = commandProject("keyed", .fake)
        project.selectLayer("comp-1-layer-2")
        let lifted = CatalogConformance.check(HaloHeadless.self, fixture: HaloHeadless(workspace: project)).map(key)
        // The CLI leaves file commands to itself, so the drop the project runs is refused there (HF-3).
        #expect(Set(lifted) == Set(CatalogConformance.check(HaloProject.self, fixture: project).map(key) + ["file.drop: exampleRuns"]))
    }

    @Test func renderFrameDrawsTheAskedFrameAtTheAskedScale() throws {
        var doc = try HaloHeadless.open(Self.input("render-frame", "shapes.halo"), name: "shapes.halo")
        _ = try HaloHeadless.catalog.run("timeline.scrub", params: .object(["frame": .number(12)]), on: &doc)
        let atPlayhead = try doc.renderFrame(.object([:])), atZero = try doc.renderFrame(.object(["frame": .number(0)]))
        #expect([atPlayhead.frame, atZero.frame] == [12, 0] as [Int])
        #expect(try atPlayhead.pixels.rgba8() != atZero.pixels.rgba8())
        let quarter = try doc.renderFrame(.object(["scale": .number(4)]))
        #expect([quarter.pixels.width, quarter.pixels.height] == [16, 9] as [Int])
        #expect(throws: CatalogError.self) { try HaloHeadless(workspace: HaloProject(services: .fake)).renderFrame(.object([:])) }
        #expect(throws: CatalogError.self) { try doc.export("mov", options: .object([:])) }
    }

    @Test func exportWritesTheRenderedFrameAsAPNGOnEveryPlatform() throws {
        var doc = try HaloHeadless.open(Self.input("render-frame", "shapes.halo"), name: "shapes.halo")
        _ = try HaloHeadless.catalog.run("timeline.scrub", params: .object(["frame": .number(12)]), on: &doc)
        let file = try #require(try doc.export("png", options: .object([:])).first)
        #expect(file.suggestedName == "Shapes-12.png")
        let frame = try doc.renderFrame(.object([:])).pixels, png = try HaloJob.decodePNG(file.data)
        #expect([png.width, png.height] == [frame.width, frame.height] as [Int])
        #expect(png.rgba == (try frame.rgba8()))
        #expect(file.data == (try PNG.write(frame, bitsPerChannel: 8)), "core's PNG bytes, not a local writer's")
        let bytes = [UInt8](file.data)
        var at = 8, types: [String] = []
        while at + 12 <= bytes.count {
            let length = bytes[at..<(at + 4)].reduce(0) { $0 << 8 | Int($1) }
            types.append(String(decoding: bytes[(at + 4)..<(at + 8)], as: UTF8.self))
            at += 12 + length
        }
        #expect(types.first == "IHDR" && types.last == "IEND" && types.contains("IDAT"))
    }

    @Test(arguments: ["retitle-and-save", "render-frame"])
    func realJobPasses(job: String) throws {
        let problems = try HaloJob.check(job)
        #expect(problems == [], "\(job)")
    }
}

/// Runs a `Tests/RealJobs/halo/<job>/` script on HaloHeadless the way the format says (afterglow-cli.md) and checks
/// its `expect` block: JSON equal, or pixels within the tolerance of a reference PNG.
enum HaloJob {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("RealJobs/halo")
    struct Script: Decodable { var steps: [CommandEnvelope]; var atomic: Bool; var output: Output?; var expect: [String: JSONValue] }
    struct Output: Decodable { var name: String; var format: String; var options: JSONValue }
    struct Pixels: Decodable { var tolerance: Int; var reference: String }

    /// Every expectation of `job` that failed, in words; empty when the job passes.
    static func check(_ job: String) throws -> [String] {
        let folder = root.appendingPathComponent(job)
        let script = try JSONDecoder().decode(Script.self, from: Data(contentsOf: folder.appendingPathComponent("\(job).jobs.json")))
        let inputs = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("input").path).filter { $0.hasSuffix(".halo") }.sorted()
        var outputs: [String: HaloHeadless] = [:]
        for name in inputs {
            var doc = try HaloHeadless.open(Data(contentsOf: folder.appendingPathComponent("input/\(name)")), name: name)
            let report = HaloHeadless.catalog.runBatch(script.steps, on: &doc, atomic: script.atomic)
            guard report.stoppedAt == nil else { return ["\(name): \(report.steps.compactMap(\.error))"] }
            let stem = String(name.dropLast(".halo".count))
            let out = script.output.map { "out/\($0.name.replacingOccurrences(of: "{stem}", with: stem)).\($0.format)" } ?? "out/\(stem).halo"
            outputs[out] = doc
        }
        return try script.expect.sorted { $0.key < $1.key }.flatMap { path, expectation -> [String] in
            guard let doc = outputs[path], case .object(let kind) = expectation else { return ["\(path): not written"] }
            if let json = kind["json"] {
                return try JSONValue(json: doc.save()) == json ? [] : ["\(path): the saved JSON differs"]
            }
            let pixels = try (kind["pixels"] ?? .null).decode(Pixels.self)
            let want = try decodePNG(Data(contentsOf: folder.appendingPathComponent(pixels.reference)))
            let got = try produced(doc, script.output?.options ?? .object([:]))
            guard got.width == want.width, got.height == want.height, got.rgba.count == want.rgba.count else {
                return ["\(path): \(got.width)x\(got.height), not \(want.width)x\(want.height)"]
            }
            let worst = zip(got.rgba, want.rgba).map { abs(Int($0) - Int($1)) }.max() ?? 0
            return worst <= pixels.tolerance ? [] : ["\(path): a channel is off by \(worst)"]
        }
    }

    /// The PNG `export` writes, decoded.
    static func produced(_ doc: HaloHeadless, _ options: JSONValue) throws -> (width: Int, height: Int, rgba: [UInt8]) {
        try decodePNG(try #require(doc.export("png", options: options).first).data)
    }

    /// An 8-bit RGBA, non-interlaced PNG's pixels (W3C PNG, chunks, zlib and the five filters); enough for references.
    static func decodePNG(_ data: Data) throws -> (width: Int, height: Int, rgba: [UInt8]) {
        let b = [UInt8](data)
        func be(_ at: Int) -> Int { b[at..<at + 4].reduce(0) { $0 << 8 | Int($1) } }
        var i = 8, idat = [UInt8](), w = 0, h = 0
        while i + 12 <= b.count {
            let n = be(i), type = String(decoding: b[(i + 4)..<(i + 8)], as: UTF8.self)
            if type == "IHDR" { (w, h) = (be(i + 8), be(i + 12)); try #require(b[(i + 16)..<(i + 21)] == [8, 6, 0, 0, 0]) }
            if type == "IDAT" { idat += b[(i + 8)..<(i + 8 + n)] }
            i += 12 + n
        }
        let stride = w * 4, raw = [UInt8](try Inflate.zlib(Data(idat), limit: h * (stride + 1)))
        try #require(raw.count == h * (stride + 1))
        var out = [UInt8](repeating: 0, count: h * stride)
        for y in 0..<h {
            let filter = raw[y * (stride + 1)]
            for x in 0..<stride {
                let a = x >= 4 ? Int(out[y * stride + x - 4]) : 0, up = y > 0 ? Int(out[(y - 1) * stride + x]) : 0
                let c = x >= 4 && y > 0 ? Int(out[(y - 1) * stride + x - 4]) : 0
                let p = a + up - c, (pa, pb, pc) = (abs(p - a), abs(p - up), abs(p - c))
                let predictor = switch filter {
                case 1: a
                case 2: up
                case 3: (a + up) / 2
                case 4: pa <= pb && pa <= pc ? a : (pb <= pc ? up : c)
                default: 0
                }
                out[y * stride + x] = UInt8(truncatingIfNeeded: Int(raw[y * (stride + 1) + 1 + x]) + predictor)
            }
        }
        return (w, h, out)
    }
}
