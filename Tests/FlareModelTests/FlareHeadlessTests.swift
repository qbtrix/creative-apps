// FlareHeadlessTests.swift (adopt-command-catalog AC-f3): FlareHeadless opens, saves, makes, summarizes, lifts
// FlareWorkspace's catalog and exports SVG frames and Lottie on Linux, refusing PNG; Tests/RealJobs/flare's jobs run
// here through `FlareJob` (json compared equal; a sha256's digest is the CLI's RealJobsTests' to check).
import FlareCore
import Foundation
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlareHeadlessTests {
    /// A 12-frame scene whose square "ball" moves x 0 → 110 over frames 0...11, so every frame draws differently.
    static func keyed() throws -> FlareHeadless {
        var doc = try FlareHeadless.new(.object(["width": .number(200), "height": .number(100), "durationFrames": .number(12)]))
        let square = [(0.0, 0.0), (20, 0), (20, 20), (0, 20)].map { FlareCore.Point(x: $0.0, y: $0.1) }
        let steps: [any FlareCore.Command] = [
            AddLayer(owner: .scene("scene-1"), layer: Layer(id: "layer-1", name: "Ball", shapes: [FlareShape(points: square)])),
            SetKeyframe(owner: .scene("scene-1"), layerID: "layer-1", property: "x", keyframe: FlareCore.Keyframe(frame: 0, value: 0)),
            SetKeyframe(owner: .scene("scene-1"), layerID: "layer-1", property: "x", keyframe: FlareCore.Keyframe(frame: 11, value: 110)),
        ]
        for step in steps {
            _ = try FlareHeadless.catalog.run(FlareWorkspace.catalogID(type(of: step).id), params: JSONValue(encoding: step), on: &doc)
        }
        return doc
    }

    @Test func openSaveReopenIsTheSameDocument() throws {
        let doc = try Self.keyed()
        let reopened = try FlareHeadless.open(doc.save(), name: "ball.flare")
        #expect(reopened.workspace.document == doc.workspace.document)
        #expect(try reopened.save() == doc.save())
        #expect(reopened.workspace.title == "ball")
        #expect(throws: CatalogError.self) { try FlareHeadless.open(Data("nope".utf8), name: "x.flare") }
        #expect(throws: CatalogError.self) { try FlareHeadless.open(doc.save(), name: "x.svg") }
    }

    @Test func newAndSummary() throws {
        let doc = try FlareHeadless.new(.object(["width": .number(320), "height": .number(240), "fps": .number(12)]))
        let scene = try #require(doc.workspace.selectedScene)
        #expect([scene.width, scene.height] == [320, 240] && scene.fps == 12 && scene.durationFrames == 48)
        #expect(doc.summary() == .object([
            "app": .string("flare"), "name": .null, "selectedScene": .string("scene-1"), "currentFrame": .number(0),
            "scenes": .array([.object(["id": .string("scene-1"), "name": .string(scene.name), "width": .number(320),
                                       "height": .number(240), "fps": .number(12), "frames": .number(48), "layers": .number(0)])]),
        ]))
        #expect(throws: CatalogError.self) { try FlareHeadless.new(.object(["fps": .number(0)])) }
    }

    @Test func theCatalogIsFlareWorkspacesWithFileCommandsLeftToTheCLI() throws {
        #expect(FlareHeadless.catalog.ids == FlareWorkspace.catalog.ids)
        let doc = try Self.keyed()
        for spec in FlareWorkspace.commands {
            let expected = spec.kind == .file ? .unavailable(FlareHeadless.fileCommandHelp) : spec.availability(doc.workspace)
            #expect(FlareHeadless.catalog.availability(spec.id, on: doc) == expected, "\(spec.id)")
        }
    }

    @Test func exportWritesEachAskedFrameAsCoresSVG() throws {
        let doc = try Self.keyed()
        let scene = try #require(doc.workspace.selectedScene)
        let files = try doc.export("svg", options: .object(["frames": .array([.number(0), .number(6), .number(11)])]))
        #expect(files.map(\.suggestedName) == ["scene-1-0.svg", "scene-1-6.svg", "scene-1-11.svg"])
        for (file, frame) in zip(files, [0, 6, 11]) {
            #expect(file.format == "svg")
            #expect(String(decoding: file.data, as: UTF8.self) == (try SVGExporter.export(scene: scene, frame: Double(frame))), "frame \(frame)")
        }
        #expect(Set(files.map(\.data)).count == 3)
        #expect(try doc.export("svg", options: .object([:])).map(\.suggestedName) == ["scene-1-0.svg"]) // the current frame
        #expect(throws: CatalogError.self) { try doc.export("svg", options: .object(["frames": .array([.number(12)])])) }
    }

    @Test func exportWritesLottieForTheAskedSceneAndRefusesPNG() throws {
        var doc = try Self.keyed()
        let second = FlareScene(id: "scene-2", name: "Two", durationFrames: 6)
        _ = try FlareHeadless.catalog.run("scene.add", params: JSONValue(encoding: AddScene(scene: second)), on: &doc)
        let lottie = try doc.export("lottie", options: .object(["scene": .string("scene-2")]))
        #expect(lottie == [ExportedFile(suggestedName: "scene-2.json", format: "lottie", data: try LottieExporter.export(scene: second))])
        #expect(throws: CatalogError.self) { try doc.export("lottie", options: .object(["scene": .string("scene-9")])) }
        #expect(throws: CatalogError.self) { try doc.export("png", options: .object([:])) }
        #expect(throws: CatalogError.self) { try doc.export("gif", options: .object([:])) }
        #expect(FlareHeadless.openExtensions == ["flare"] && FlareHeadless.exportFormats == ["svg", "lottie"])
    }

    @Test(arguments: ["export-svg-frames", "key-and-save"])
    func realJobPasses(job: String) throws {
        #expect(try FlareJob.check(job) == [], "\(job)")
    }
}

/// Runs a `Tests/RealJobs/flare/<job>/` script on FlareHeadless the way the format says (afterglow-cli.md): the
/// native format saves, any other exports one file. A json expectation is compared equal; a sha256 one must be
/// written (the CLI's RealJobsTests compares its digest).
enum FlareJob {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("RealJobs/flare")
    struct Script: Decodable { var steps: [CommandEnvelope], atomic: Bool, output: Output, expect: [String: JSONValue] }
    struct Output: Decodable { var name: String; var format: String; var options: JSONValue? }

    /// Every expectation of `job` that failed, in words; empty when the job passes.
    static func check(_ job: String) throws -> [String] {
        let folder = root.appendingPathComponent(job)
        let script = try JSONDecoder().decode(Script.self, from: Data(contentsOf: folder.appendingPathComponent("\(job).jobs.json")))
        let inputs = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("input").path)
            .filter { $0.hasSuffix(".flare") }.sorted()
        var outputs: [String: Data] = [:]
        for name in inputs {
            var doc = try FlareHeadless.open(Data(contentsOf: folder.appendingPathComponent("input/\(name)")), name: name)
            let report = FlareHeadless.catalog.runBatch(script.steps, on: &doc, atomic: script.atomic)
            guard report.stoppedAt == nil else { return ["\(name): \(report.steps.compactMap(\.error))"] }
            let stem = String(name.dropLast(".flare".count)), o = script.output
            let path = "out/\(o.name.replacingOccurrences(of: "{stem}", with: stem)).\(o.format)"
            let files = o.format == "flare" ? [try doc.save()] : try doc.export(o.format, options: o.options ?? .object([:])).map(\.data)
            guard files.count == 1 else { return ["\(path): \(files.count) files, not one"] }
            outputs[path] = files.first
        }
        return try script.expect.sorted { $0.key < $1.key }.flatMap { path, expectation -> [String] in
            guard let data = outputs[path], case .object(let kind) = expectation else { return ["\(path): not written"] }
            if let want = kind["json"] { return try JSONValue(json: data) == want ? [] : ["\(path): JSON differs"] }
            return kind["sha256"] == nil ? ["\(path): unknown expectation"] : []
        }
    }
}
