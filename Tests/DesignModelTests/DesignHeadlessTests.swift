// DesignHeadlessTests.swift (adopt-command-catalog AC-d2): DesignHeadless opens, saves, makes, summarizes, lifts the
// workspace's catalog and exports SVG; Tests/RealJobs/design's two jobs run here through `DesignJob` until the CLI's
// RealJobs harness (CL-9) runs them. Fails when a round trip loses a layer or a job's output differs. Linux-safe.
@testable import DesignModel
import Foundation
import SuiteKernel
import Testing

@Suite struct DesignHeadlessTests {
    static func input(_ job: String, _ name: String) throws -> Data {
        try Data(contentsOf: DesignJob.root.appendingPathComponent("\(job)/input/\(name)"))
    }

    static func layers(_ doc: DesignHeadless) -> [JSONValue] {
        guard case .object(let summary) = doc.summary(), case .array(let pages) = summary["pages"] else { return [] }
        return pages.compactMap { if case .object(let page) = $0 { page["layers"] } else { nil } }
    }

    @Test func opensSavesAndReopensWithEveryLayer() throws {
        let data = try Self.input("export-frames-svg", "loose-front.design")
        let doc = try DesignHeadless.open(data, name: "loose-front.design")
        #expect(try doc.save() == data)
        #expect(Self.layers(doc) == [.number(1), .number(2)])
        let again = try DesignHeadless.open(doc.save(), name: "copy.design")
        #expect(Self.layers(again) == Self.layers(doc))
        #expect(again.workspace.pages == doc.workspace.pages)
        #expect(throws: CatalogError.failed(id: "file.open", message: DesignFileError.unreadable.reason)) {
            try DesignHeadless.open(Data("{}".utf8), name: "x.design")
        }
    }

    @Test func newIsFileNewAndRoundTrips() throws {
        let doc = try DesignHeadless.new(.object([:]))
        #expect(doc.name == "Untitled.design")
        #expect(doc.workspace.pages.count == 1 && Self.layers(doc) == [.number(1)])
        #expect(try DesignHeadless.open(doc.save(), name: "n.design").workspace.pages == doc.workspace.pages)
        #expect(throws: CatalogError.failed(id: "file.save", message: DesignFileError.noFile.reason)) {
            try DesignHeadless(DesignWorkspace()).save()
        }
    }

    @Test func summaryNamesTheFilePagesAndSelection() throws {
        var doc = DesignHeadless(DesignFixtures.twoPages, name: "pages.design")
        _ = try DesignHeadless.catalog.run("edit.select-all", params: .object([:]), on: &doc)
        guard case .object(let summary) = doc.summary() else { Issue.record("not an object"); return }
        #expect(summary["app"] == .string("design") && summary["name"] == .string("pages.design"))
        #expect(summary["selectedPage"] == doc.workspace.selectedPageID.map(JSONValue.string))
        #expect(summary["selection"] == .array(doc.workspace.selectedNodeIDs.map(JSONValue.string)) && !doc.workspace.selectedNodeIDs.isEmpty)
    }

    @Test func theCatalogIsTheWorkspacesAndRecordsUndo() throws {
        #expect(DesignHeadless.catalog.ids == DesignWorkspace.catalog.ids)
        var doc = DesignHeadless(DesignFixtures.cards)
        for spec in DesignWorkspace.commands {
            #expect(DesignHeadless.catalog.availability(spec.id, on: doc) == spec.availability(doc.workspace), "\(spec.id)")
        }
        _ = try DesignHeadless.catalog.run("edit.select", params: .object(["ids": .array([.string("node-2")])]), on: &doc)
        let nudge = try DesignHeadless.catalog.run("object.nudge", params: .object(["direction": .string("right")]), on: &doc)
        #expect(nudge.undoStep == "Nudge" && doc.workspace.frame("node-2")?.x == 101)
    }

    @Test func exportsEveryFrameOfEveryPageAsSVGAndRefusesOtherFormats() throws {
        var doc = try DesignHeadless.open(Self.input("export-frames-svg", "loose-front.design"), name: "loose-front.design")
        #expect(try doc.export("svg", options: .object([:])).map(\.suggestedName) == ["Back.svg"])
        var framed = doc.workspace
        framed.pages[0].nodes = [DesignNode(id: "node-1", name: "Cover", kind: .frame, frame: DesignRect(x: 0, y: 0, width: 320, height: 200),
                                            children: framed.pages[0].nodes, fill: DesignColor(255, 255, 255))]
        doc = DesignHeadless(framed, name: "two-frames.design")
        _ = try DesignHeadless.catalog.run("page.select", params: .object(["page": .string("page-2")]), on: &doc)
        let files = try doc.export("svg", options: .object([:]))
        #expect(files.map(\.suggestedName) == ["Cover.svg", "Back.svg"] && files.allSatisfy { $0.format == "svg" })
        #expect(throws: CatalogError.notBuilt(id: "export.png", feature: "a Linux PNG writer for Design's raster path")) {
            try doc.export("png", options: .object([:]))
        }
        #expect(throws: CatalogError.self) { try doc.export("pdf", options: .object([:])) }
        let frameless = try DesignHeadless.open(Self.input("align-and-save", "three-cards.design"), name: "three-cards.design")
        #expect(throws: CatalogError.self) { try frameless.export("svg", options: .object([:])) }
    }

    /// `scope` picks what the CLI writes; any other option, or a scope it doesn't name, fails in words.
    @Test func exportOptionsPickTheScopeAndRefuseTheRest() throws {
        var doc = DesignHeadless(DesignFixtures.cards, name: "cards.design")
        #expect(try doc.export("svg", options: .object(["scope": .string("frame")])).map(\.suggestedName) == ["Desktop.svg"])
        #expect(try doc.export("svg", options: .null).map(\.suggestedName) == ["Desktop.svg"])
        let page = try #require(doc.workspace.selectedPage?.name)
        #expect(try doc.export("svg", options: .object(["scope": .string("page")])).map(\.suggestedName) == ["\(page).svg"])
        #expect(throws: CatalogError.failed(id: "export", message: "Select a layer first.")) {
            try doc.export("svg", options: .object(["scope": .string("selection")]))
        }
        _ = try DesignHeadless.catalog.run("edit.select", params: .object(["ids": .array([.string("node-2")])]), on: &doc)
        #expect(try doc.export("svg", options: .object(["scope": .string("selection")])).map(\.suggestedName) == ["A.svg"])
        #expect(throws: ExportOptionRefusal.invalid("Design's SVG export takes one option, scope (selection, frame, page), not scale.")) {
            try doc.export("svg", options: .object(["scale": .number(2)]))
        }
        #expect(throws: ExportOptionRefusal.invalid("The scope is one of selection, frame, page.")) {
            try doc.export("svg", options: .object(["scope": .string("everything")]))
        }
        #expect(throws: ExportOptionRefusal.self) { try doc.export("svg", options: .string("page")) }
    }

    @Test(arguments: ["export-frames-svg", "align-and-save"])
    func realJobPasses(job: String) throws {
        let problems = try DesignJob.check(job)
        #expect(problems == [], "\(job): \(problems)")
    }
}

/// Runs a `Tests/RealJobs/design/<job>/` script on DesignHeadless the way the format says (afterglow-cli.md) and checks
/// its `expect` block. An export that writes several files writes them under a folder named by the `name` template.
enum DesignJob {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("RealJobs/design")
    struct Script: Decodable { var steps: [CommandEnvelope]; var atomic: Bool; var output: Output?; var expect: [String: JSONValue] }
    struct Output: Decodable { var dir: String; var name: String; var format: String; var options: JSONValue }

    /// Every expectation of `job` that failed, in words; empty when the job passes.
    static func check(_ job: String) throws -> [String] {
        let folder = root.appendingPathComponent(job)
        let script = try JSONDecoder().decode(Script.self, from: Data(contentsOf: folder.appendingPathComponent("\(job).jobs.json")))
        let inputs = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("input").path).filter { $0.hasSuffix(".design") }.sorted()
        var written: [String: Data] = [:]
        for name in inputs {
            var doc = try DesignHeadless.open(Data(contentsOf: folder.appendingPathComponent("input/\(name)")), name: name)
            let report = DesignHeadless.catalog.runBatch(script.steps, on: &doc, atomic: script.atomic)
            guard report.stoppedAt == nil else { return ["\(name): \(report.steps.compactMap(\.error))"] }
            let stem = String(name.dropLast(".design".count))
            guard let output = script.output else { written["out/\(stem).design"] = try doc.save(); continue }
            let named = "\(output.dir)/\(output.name.replacingOccurrences(of: "{stem}", with: stem))"
            let files = try doc.export(output.format, options: output.options)
            for file in files { written[files.count == 1 ? "\(named).\(output.format)" : "\(named)/\(file.suggestedName)"] = file.data }
        }
        var problems = Set(written.keys).subtracting(script.expect.keys).sorted().map { "\($0): written but not expected" }
        for (path, expectation) in script.expect.sorted(by: { $0.key < $1.key }) {
            guard let data = written[path], case .object(let kind) = expectation else { problems.append("\(path): not written"); continue }
            if let json = kind["json"], try JSONValue(json: data) != json { problems.append("\(path): the saved JSON differs") }
            if case .string(let hash)? = kind["sha256"], sha256(data) != hash { problems.append("\(path): sha256 \(sha256(data)), not \(hash)") }
        }
        return problems
    }

    /// SHA-256 (FIPS 180-4) as lowercase hex; the jobs' `sha256` values are what `sha256sum` prints.
    static func sha256(_ data: Data) -> String {
        let k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01,
            0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
            0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
            0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08,
            0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
            0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
        ]
        var h: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
        var bytes = [UInt8](data) + [0x80]
        while bytes.count % 64 != 56 { bytes.append(0) }
        bytes += (0..<8).map { UInt8(truncatingIfNeeded: (UInt64(data.count) * 8) >> (56 - 8 * $0)) }
        func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 { x >> n | x << (32 - n) }
        for chunk in stride(from: 0, to: bytes.count, by: 64) {
            var w = (0..<16).map { i in (0..<4).reduce(UInt32(0)) { $0 << 8 | UInt32(bytes[chunk + 4 * i + $1]) } }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ w[i - 15] >> 3, s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ w[i - 2] >> 10
                w.append(w[i - 16] &+ s0 &+ w[i - 7] &+ s1)
            }
            var (a, b, c, d, e, f, g, hh) = (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7])
            for i in 0..<64 {
                let t1 = hh &+ (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) &+ (e & f ^ ~e & g) &+ k[i] &+ w[i]
                let t2 = (rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) &+ (a & b ^ a & c ^ b & c)
                (hh, g, f, e, d, c, b, a) = (g, f, e, d &+ t1, c, b, a, t1 &+ t2)
            }
            h = zip(h, [a, b, c, d, e, f, g, hh]).map { $0 &+ $1 }
        }
        return h.map { word in (0..<8).map { String(word >> (28 - 4 * UInt32($0)) & 0xf, radix: 16) }.joined() }.joined()
    }
}
