// FakeToneTests.swift (tone-controls TC-9): the CLI's `fake-tone` app, FakeToneDocument. Tone survives save and open,
// neutral tone writes `{}`, a drag is one undo step, the fake canvas app is untouched, and RJ-X41's steps, run through
// the catalog on its input, save what its job expects. Mutations: SuiteImaging.FakeToneDocument
// (`.neutralWritesNothing`, `.dragIsOneStep`).
import Foundation
import SuiteImaging
import SuiteKernel
import Testing

@Suite struct FakeToneTests {
    let catalog = FakeToneDocument.catalog
    /// RJ-X41's folder.
    static let job = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("RealJobs/fake-tone/tone-controls")

    func set(_ slider: String, _ value: Double, drag: String? = nil) -> JSONValue {
        var params: [String: JSONValue] = ["slider": .string(slider), "value": .number(value)]
        if let drag { params["drag"] = .string(drag) }
        return .object(params)
    }

    /// The catalog lists the four tone commands and undo and redo; the app opens `.fake-tone` and exports json.
    @Test func theAppAndItsCommands() {
        #expect(catalog.ids == ["edit.redo", "edit.undo", "tone.auto", "tone.read", "tone.reset", "tone.set"])
        #expect(FakeToneDocument.app == "fake-tone" && FakeToneDocument.openExtensions == ["fake-tone"])
        #expect(FakeToneDocument.exportFormats == ["json"])
    }

    /// Set tone saves as `{"tone": {...}}` with only the sliders off neutral and opens back the same, with no steps.
    @Test func toneSurvivesSaveAndOpen() throws {
        var doc = FakeToneDocument()
        _ = try catalog.run("tone.set", params: set("temperature", 35), on: &doc)
        _ = try catalog.run("tone.set", params: set("shadows", -20), on: &doc)
        let saved = try doc.save()
        #expect(try JSONValue(json: saved) == .object(["tone": .object(["shadows": .number(-20), "temperature": .number(35)])]))
        let opened = try FakeToneDocument.open(saved, name: "a.fake-tone")
        #expect(opened.tone == doc.tone && opened.history.steps.isEmpty)
    }

    /// A neutral picture writes `{}`, new or set back to neutral, and `{}` opens neutral.
    @Test func neutralWritesNothing() throws {
        #expect(try FakeToneDocument().save() == Data("{}".utf8))
        var doc = FakeToneDocument()
        _ = try catalog.run("tone.set", params: set("exposure", 1.5), on: &doc)
        _ = try catalog.run("tone.reset", params: .object([:]), on: &doc)
        #expect(try doc.save() == Data("{}".utf8))
        #expect(try FakeToneDocument.open(Data("{}".utf8), name: "a.fake-tone").tone == .neutral)
    }

    /// 120 samples under one drag token are one step; one undo takes back only the next edit.
    @Test func dragIsOneStep() throws {
        var doc = FakeToneDocument()
        for n in 1...120 { _ = try catalog.run("tone.set", params: set("temperature", Double(n) * 35 / 120, drag: "d1"), on: &doc) }
        _ = try catalog.run("tone.set", params: set("shadows", 40), on: &doc)
        #expect(doc.history.steps == ["Temperature", "Shadows"])
        #expect(try catalog.run("edit.undo", params: .object([:]), on: &doc).result == .bool(true))
        #expect(doc.tone.value(.shadows) == 0 && doc.tone.value(.temperature) == 35)
    }

    /// Vibrance is refused with `ToneRules.waiting`'s reason and records nothing.
    @Test func vibranceIsRefused() {
        var doc = FakeToneDocument()
        let why = ToneRules.waiting[.vibrance] ?? ""
        #expect(throws: CatalogError.unavailable(id: "tone.set", why: why)) { try catalog.run("tone.set", params: set("vibrance", 20), on: &doc) }
        #expect(doc.history.steps.isEmpty)
    }

    /// The fake canvas app takes no tone: its catalog has no tone command and every one of its jobs names it alone.
    @Test func fakeCanvasJobsUntouched() throws {
        #expect(!FakeCanvasDocument.catalog.ids.contains { $0.hasPrefix("tone.") })
        #expect(FakeToneDocument.app != FakeCanvasDocument.app)
        let fake = Self.job.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("fake")
        let jobs = try FileManager.default.contentsOfDirectory(atPath: fake.path)
        #expect(!jobs.isEmpty && !jobs.contains("tone-controls"))
        for name in jobs {
            let folder = fake.appendingPathComponent(name)
            for file in try FileManager.default.contentsOfDirectory(atPath: folder.path) where file.hasSuffix(".jobs.json") {
                guard case .object(let fields) = try JSONValue(json: Data(contentsOf: folder.appendingPathComponent(file))) else { continue }
                #expect(fields["app"] == .string("fake"), "\(name) names \(String(describing: fields["app"]))")
            }
        }
    }

    /// RJ-X41: the job's steps, run through the catalog on its neutral input, export what its `expect` holds.
    @Test func realJobX41() throws {
        guard case .object(let job) = try JSONValue(json: Data(contentsOf: Self.job.appendingPathComponent("tone-controls.jobs.json"))),
              case .array(let steps)? = job["steps"], case .object(let expect)? = job["expect"],
              case .object(let want)? = expect["out/one-toned.json"], let json = want["json"] else {
            Issue.record("tone-controls.jobs.json has no steps and out/one-toned.json"); return
        }
        var doc = try FakeToneDocument.open(Data(contentsOf: Self.job.appendingPathComponent("input/one.fake-tone")), name: "one.fake-tone")
        #expect(doc.tone == .neutral)
        for case .object(let step) in steps {
            guard case .string(let id)? = step["id"] else { continue }
            _ = try catalog.run(id, params: step["params"] ?? .object([:]), on: &doc)
        }
        let exported = try doc.export("json", options: .object([:]))
        #expect(exported.count == 1)
        #expect(try JSONValue(json: exported.first?.data ?? Data()) == json)
        #expect(json == .object(["tone": .object(["temperature": .number(35)])]))
    }
}
