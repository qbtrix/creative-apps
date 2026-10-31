// PhotoHeadlessTests.swift (adopt-command-catalog AC-p2): PhotoHeadless opens, saves, makes, summarizes, lifts
// PhotoWorkspace's catalog and exports PNG through CoreRasterImageCodec; Tests/RealJobs/photo's jobs run here through
// `PhotoJob` until the CLI's RealJobs harness runs them, each output within its tolerance of the reference PNG.
import CoreRaster
import Foundation
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoHeadlessTests {
    /// 3 x 2 straight sRGB pixels: opaque, half and quarter see-through, and clear.
    static let pixels: [UInt8] = [255, 0, 0, 255, 0, 0, 255, 128, 0, 255, 0, 64, 255, 255, 0, 255, 40, 80, 120, 200, 0, 0, 0, 0]
    static func png(_ rgba: [UInt8] = pixels, width: Int = 3, height: Int = 2) throws -> Data {
        try PhotoHeadless.codec.encode(DecodedImage(rgba8: rgba, width: width, height: height), as: .png, quality: 1)
    }

    @Test func pngRoundTripExact() throws {
        let doc = try PhotoHeadless.open(Self.png(), name: "dots.png")
        let file = try #require(doc.export("png", options: .object([:])).first)
        #expect(file.suggestedName == "dots.png")
        let back = try PhotoHeadless.codec.decode(file.data, longestSide: nil)
        #expect([back.width, back.height] == [3, 2] as [Int])
        #expect(back.rgba8 == Self.pixels)
    }

    @Test func openSaveReopenIsTheSameDocument() throws {
        var doc = try PhotoHeadless.new(.object(["width": .number(8), "height": .number(6)]))
        let paste: JSONValue = .object(["width": .number(3), "height": .number(2), "rgba8": .array(Self.pixels.map { .number(Double($0)) })])
        _ = try PhotoHeadless.catalog.run("edit.paste", params: paste, on: &doc)
        let reopened = try PhotoHeadless.open(doc.save(), name: "two.ora")
        #expect(try reopened.workspace.snapshot() == doc.workspace.snapshot()) // the canvas, not a layer's size
        #expect(reopened.workspace.layers.count == 2)
        #expect(throws: CatalogError.self) { try PhotoHeadless.open(Data(), name: "x.gif") }
    }

    @Test func newAndSummary() throws {
        let doc = try PhotoHeadless.new(.object(["width": .number(20), "height": .number(10)]))
        guard case .object(let s) = doc.summary() else { Issue.record("not an object"); return }
        #expect([s["app"], s["width"], s["height"]] == [.string("photo"), .number(20), .number(10)])
        guard case .array(let layers) = s["layers"] else { Issue.record("no layers"); return }
        #expect(layers.count == 1)
        #expect(try PhotoHeadless.new(.object([:])).workspace.canvas.map { [$0.width, $0.height] } == [1024, 768])
        #expect(throws: CatalogError.self) { try PhotoHeadless.new(.object(["width": .number(0)])) }
    }

    @Test func theCatalogIsPhotoWorkspacesWithFileCommandsLeftToTheCLI() throws {
        #expect(PhotoHeadless.catalog.ids == PhotoWorkspace.catalog.ids)
        let doc = try PhotoHeadless.new(.object(["width": .number(4), "height": .number(4)]))
        for spec in PhotoWorkspace.commands {
            let expected = spec.kind == .file && spec.id != "file.drop" ? .unavailable(PhotoHeadless.fileCommandHelp) : spec.availability(doc.workspace)
            #expect(PhotoHeadless.catalog.availability(spec.id, on: doc) == expected, "\(spec.id)")
        }
    }

    @Test func exportResizesToTheLongSideAndRefusesOtherFormats() throws {
        let doc = try PhotoHeadless.open(Self.png(), name: "dots.png")
        let file = try #require(doc.export("png", options: .object(["longSide": .number(9)])).first)
        let big = try PhotoHeadless.codec.decode(file.data, longestSide: nil)
        #expect([big.width, big.height] == [9, 6] as [Int])
        #expect(throws: CatalogError.self) { try doc.export("tiff", options: .object([:])) }
        do { _ = try doc.export("jpeg", options: .object([:])) } catch let error as CodecError {
            guard case .unsupported = error else { Issue.record("\(error)"); return } // core's JPEG waits on IC-jpeg
        }
    }

    @Test(arguments: ["batch-resize"])
    func realJobPasses(job: String) throws {
        #expect(try PhotoJob.check(job) == [], "\(job)")
    }
}

/// Runs a `Tests/RealJobs/photo/<job>/` script on PhotoHeadless the way the format says (afterglow-cli.md) and
/// checks its `expect` block: pixels within the tolerance of a reference PNG. A pending job must name its gap.
enum PhotoJob {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("RealJobs/photo")
    struct Script: Decodable {
        var pending: String?
        var steps: [CommandEnvelope], atomic: Bool, output: Output, expect: [String: JSONValue]
    }
    struct Output: Decodable { var name: String; var format: String; var options: JSONValue }
    struct Pixels: Decodable { var tolerance: Int; var reference: String }

    /// Every expectation of `job` that failed, in words; empty when the job passes or is pending on a gap.
    static func check(_ job: String) throws -> [String] {
        let folder = root.appendingPathComponent(job)
        let script = try JSONDecoder().decode(Script.self, from: Data(contentsOf: folder.appendingPathComponent("\(job).jobs.json")))
        if let gap = script.pending { return gap.hasPrefix("#") ? [] : ["pending names no gap: \(gap)"] }
        let inputs = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("input").path)
            .filter { $0.hasSuffix(".png") }.sorted()
        var outputs: [String: Data] = [:]
        for name in inputs {
            var doc = try PhotoHeadless.open(Data(contentsOf: folder.appendingPathComponent("input/\(name)")), name: name)
            let report = PhotoHeadless.catalog.runBatch(script.steps, on: &doc, atomic: script.atomic)
            guard report.stoppedAt == nil else { return ["\(name): \(report.steps.compactMap(\.error))"] }
            let stem = String(name.dropLast(".png".count)), o = script.output
            let path = "out/\(o.name.replacingOccurrences(of: "{stem}", with: stem)).\(o.format)"
            outputs[path] = try doc.export(o.format, options: o.options).first?.data
        }
        return try script.expect.sorted { $0.key < $1.key }.flatMap { path, expectation -> [String] in
            guard let data = outputs[path], case .object(let kind) = expectation else { return ["\(path): not written"] }
            let pixels = try (kind["pixels"] ?? .null).decode(Pixels.self)
            let want = try PNG.read(Data(contentsOf: folder.appendingPathComponent(pixels.reference)))
            let got = try PNG.read(data)
            guard got.width == want.width, got.height == want.height else {
                return ["\(path): \(got.width)x\(got.height), not \(want.width)x\(want.height)"]
            }
            let worst = try zip(got.rgba8(), want.rgba8()).map { abs(Int($0) - Int($1)) }.max() ?? 0
            return worst <= pixels.tolerance ? [] : ["\(path): a channel is off by \(worst)"]
        }
    }
}
