// BatchTests.swift: LJ2 and the CL-batch checks (afterglow-cli CL-6), written
// first by CL-6 and turned on by CL-7, which fills ScriptRunner over
// command-catalog CC-7's runBatch. `afterglow run <script.jobs.json>`
// validates the whole script before any input runs, expands its inputs
// relative to the script in sorted order, plans every output and refuses collisions before writing,
// runs each input all or none when atomic, and prints one report.
//
// Fixtures/Batch/ holds the canonical scripts, inputs and the expected report;
// they are read from disk by #filePath and loaded into a FakeIO under `batch/`,
// so the script is `batch/resize.jobs.json` and its inputs `batch/input/*.fake`.
// Paths in the report are the paths as `CLIIO.read` takes them.
//
// Exit codes: 0 ok; 64 an unknown app or step id; 65 a bad version, a malformed
// script or an input pattern matching nothing; 70 a run in which a step refused
// some input (the report is still printed); 73 a planned output that exists
// (no --force) or two inputs planning one path; 74 a missing script.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AfterGlowCLICore
import Testing

struct BatchTests {
    static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures").appendingPathComponent("Batch")
    static let fixtureNames = ["resize.jobs.json", "atomic.jobs.json", "input/beach.fake", "input/city.fake",
                               "input/dune.fake", "mixed/a.fake", "mixed/b.fake", "mixed/c.fake"]
    static let apps = Apps.all + [Apps.fake]
    static let outputs = ["batch/out/beach-small.fake", "batch/out/city-small.fake", "batch/out/dune-small.fake"]

    static func fixture(_ name: String) throws -> Data { try Data(contentsOf: fixtures.appendingPathComponent(name)) }

    /// The fixture folder as a FakeIO under `batch/`, plus `extra` files.
    static func world(_ extra: [String: Data] = [:]) throws -> FakeIO {
        var files = extra
        for name in fixtureNames { files["batch/" + name] = try fixture(name) }
        return FakeIO(files: files)
    }

    /// `resize.jobs.json` with `edit` applied, as script bytes.
    static func variant(_ edit: (inout [String: JSONValue]) -> Void) throws -> Data {
        guard case .object(var script) = try JSONValue(json: fixture("resize.jobs.json")) else { return Data() }
        edit(&script)
        return try JSONValue.object(script).json()
    }

    /// One run's exit code and its stdout parsed as the one JSON object it must be.
    struct Run { let code: Int32; let lines: [String]; let report: JSONValue? }

    static func run(_ script: String, io: FakeIO, dryRun: Bool = false, force: Bool = false) -> Run {
        let code = ScriptRunner.run(script, apps: apps, dryRun: dryRun, force: force, io: io)
        let report = io.stdout.count == 1 ? io.stdout.first.flatMap { try? JSONValue(json: Data($0.utf8)) } : nil
        return Run(code: code, lines: io.stdout, report: report)
    }

    static func rects(_ io: FakeIO, _ path: String) throws -> [FakeRect] {
        try JSONDecoder().decode([FakeRect].self, from: io.read(path))
    }

    static let resized = [FakeRect(id: 1, name: "Rect 1", x: 15, y: 15, w: 100, h: 60),
                          FakeRect(id: 2, name: "Badge", x: 0, y: 0, w: 8, h: 8)]

    // MARK: LJ2

    /// LJ2 step 1: three inputs write three `{stem}-small.fake` outputs, each the input after the steps.
    @Test func resizeWritesThreeOutputsByName() throws {
        let io = try Self.world()
        let run = Self.run("batch/resize.jobs.json", io: io)
        #expect(run.code == 0)
        #expect(io.files.keys.filter { $0.hasPrefix("batch/out/") }.sorted() == Self.outputs)
        for path in Self.outputs { #expect(try Self.rects(io, path) == Self.resized) }
    }

    /// The report: one JSON object, every input with every step, its outputs, and the counts.
    @Test func reportListsEveryInputAndStep() throws {
        let io = try Self.world()
        let run = Self.run("batch/resize.jobs.json", io: io)
        #expect(run.lines.count == 1)
        let expected = try JSONValue(json: Self.fixture("resize.report.json"))
        #expect(run.report == expected)
        #expect(io.stderr.isEmpty)
    }

    /// LJ2 step 2: a second run refuses the collisions and leaves the first run's outputs as they were.
    @Test func secondRunRefusesTheCollisions() throws {
        let io = try Self.world()
        #expect(Self.run("batch/resize.jobs.json", io: io).code == 0)
        let before = io.files
        let again = try Self.world(before)
        let run = Self.run("batch/resize.jobs.json", io: again)
        #expect(run.code == 73)
        #expect(again.files == before)
        #expect(run.lines.count == 1)
        #expect(run.lines.first?.contains("batch/out/beach-small.fake") == true)
        let forced = try Self.world(before)
        #expect(Self.run("batch/resize.jobs.json", io: forced, force: true).code == 0)
    }

    /// LJ2 step 3: atomic, the locked input's move refuses; its output is not written, the others are,
    /// and the report names the step and why.
    @Test func atomicPerInput() throws {
        let io = try Self.world()
        let run = Self.run("batch/atomic.jobs.json", io: io)
        #expect(run.code == 70)
        #expect(io.exists("batch/out/a-small.fake"))
        #expect(!io.exists("batch/out/b-small.fake"))
        #expect(try Self.rects(io, "batch/out/c-small.fake") == Self.resized)
        #expect(run.report?["ok"] == .bool(false))
        #expect(run.report?["written"] == .number(2))
        #expect(run.report?["refused"] == .number(1))
        let bad = run.report?["inputs"]?[1]
        #expect(bad?["input"] == .string("batch/mixed/b.fake"))
        #expect(bad?["outputs"] == .array([]))
        #expect(bad?["steps"]?.count == 2)
        #expect(bad?["steps"]?[1]?["id"] == .string("rect.move"))
        #expect(bad?["steps"]?[1]?["ok"] == .bool(false))
        #expect(bad?["steps"]?[1]?["error"]?.text?.contains("Unlock Rect 1 first.") == true)
        #expect(bad?["error"]?.text?.contains("rect.move") == true)
    }

    /// Not atomic, the locked input stops at the refusal and writes what it has: the input as it was.
    @Test func nonAtomicStopsAndWritesWhatItHas() throws {
        let io = try Self.world(["batch/mixed.jobs.json": Self.variant {
            $0["inputs"] = .array([.string("mixed/*.fake")]); $0["atomic"] = .bool(false)
        }])
        let run = Self.run("batch/mixed.jobs.json", io: io)
        #expect(run.code == 70)
        #expect(try Self.rects(io, "batch/out/b-small.fake") == Self.rects(io, "batch/mixed/b.fake"))
        #expect(run.report?["written"] == .number(3))
        #expect(run.report?["refused"] == .number(1))
    }

    // MARK: Validation before any run

    @Test(arguments: [JSONValue.number(2), .number(0), .string("1"), .null])
    func versionMustBeOne(version: JSONValue) throws {
        let io = try Self.world(["batch/v.jobs.json": Self.variant { $0["version"] = version }])
        let before = io.files
        let run = Self.run("batch/v.jobs.json", io: io)
        #expect(run.code == 65)
        #expect(run.lines.first?.contains("version") == true)
        #expect(io.files == before)
    }

    @Test func unknownAppIsAUsageError() throws {
        let io = try Self.world(["batch/app.jobs.json": Self.variant { $0["app"] = .string("paint") }])
        let run = Self.run("batch/app.jobs.json", io: io)
        #expect(run.code == 64)
        #expect(run.lines.first?.contains("paint") == true)
    }

    /// A bad id in the last step refuses the script before the first input runs: nothing is written.
    @Test func unknownStepIdRefusedBeforeAnyRun() throws {
        let io = try Self.world(["batch/bad.jobs.json": Self.variant {
            $0["steps"] = .array([.object(["id": .string("rect.select"), "params": .object(["id": .number(1)])]),
                                  .object(["id": .string("rect.explode"), "params": .object([:])])])
        }])
        let before = io.files
        let run = Self.run("batch/bad.jobs.json", io: io)
        #expect(run.code == 64)
        #expect(run.lines.count == 1)
        #expect(run.lines.first?.contains("rect.explode") == true)
        #expect(io.files == before)
    }

    @Test func missingScriptIsIOAndMalformedIsData() throws {
        let none = try Self.world()
        #expect(Self.run("batch/none.jobs.json", io: none).code == 74)
        let io = try Self.world(["batch/broken.jobs.json": Data(#"{"version": 1, "app": "#.utf8)])
        #expect(Self.run("batch/broken.jobs.json", io: io).code == 65)
    }

    // MARK: Inputs

    /// Inputs expand relative to the script, sorted across every pattern; `{index}` follows that order.
    @Test func sortedInputs() throws {
        let io = try Self.world(["batch/order.jobs.json": Self.variant {
            $0["inputs"] = .array([.string("input/dune.fake"), .string("input/c*.fake"), .string("input/beach.fake")])
            $0["output"] = .object(["dir": .string("out"), "name": .string("{index}-{stem}"), "format": .string("fake")])
        }])
        let run = Self.run("batch/order.jobs.json", io: io)
        #expect(run.code == 0)
        let inputs = run.report?["inputs"]?.items?.compactMap { $0["input"]?.text }
        #expect(inputs == ["batch/input/beach.fake", "batch/input/city.fake", "batch/input/dune.fake"])
        #expect(["batch/out/1-beach.fake", "batch/out/2-city.fake", "batch/out/3-dune.fake"].allSatisfy(io.exists))
    }

    /// An input pattern matching nothing is an error naming it, not an empty run; so is one of several.
    @Test(arguments: [["input/*.png"], ["input/*.fake", "input/*.png"]])
    func emptyMatchIsAnError(patterns: [String]) throws {
        let io = try Self.world(["batch/empty.jobs.json": Self.variant { $0["inputs"] = .array(patterns.map(JSONValue.string)) }])
        let before = io.files
        let run = Self.run("batch/empty.jobs.json", io: io)
        #expect(run.code == 65)
        #expect(run.lines.first?.contains("input/*.png") == true)
        #expect(io.files == before)
    }

    // MARK: Outputs

    /// `{stem}`, `{ext}`, `{index}` (1-based, zero-padded to the input count's width) and `{app}`.
    @Test func nameTokens() throws {
        var extra: [String: Data] = [:]
        for n in 1...12 { extra["batch/many/s\(n).fake"] = try Self.fixture("input/beach.fake") }
        extra["batch/tokens.jobs.json"] = try Self.variant {
            $0["inputs"] = .array([.string("many/*.fake")])
            $0["output"] = .object(["dir": .string("out"), "name": .string("{index}-{stem}-{ext}-{app}"), "format": .string("fake")])
        }
        let io = try Self.world(extra)
        #expect(Self.run("batch/tokens.jobs.json", io: io).code == 0)
        #expect(io.exists("batch/out/01-s1-fake-fake.fake"))
        #expect(io.exists("batch/out/12-s9-fake-fake.fake"))   // sorted: s1, s10, s11, s12, s2, ..., s9
        #expect(io.files.keys.filter { $0.hasPrefix("batch/out/") }.count == 12)
    }

    /// Without `output`, each document is saved natively next to the script under `out/`.
    @Test func noOutputSavesNativelyUnderOut() throws {
        let io = try Self.world(["batch/plain.jobs.json": Self.variant { $0["output"] = nil }])
        #expect(Self.run("batch/plain.jobs.json", io: io).code == 0)
        #expect(try Self.rects(io, "batch/out/beach.fake") == Self.resized)
    }

    /// Two inputs planning one path, or one planned output already there, refuse before any write:
    /// the earlier inputs' outputs are not written either.
    @Test func collisionsBeforeWriting() throws {
        let same = try Self.world(["batch/same.jobs.json": Self.variant {
            $0["output"] = .object(["dir": .string("out"), "name": .string("small"), "format": .string("fake")])
        }])
        let sameBefore = same.files
        #expect(Self.run("batch/same.jobs.json", io: same).code == 73)
        #expect(same.files == sameBefore)

        let last = try Self.world(["batch/out/dune-small.fake": Data("keep".utf8)])
        let lastBefore = last.files
        let run = Self.run("batch/resize.jobs.json", io: last)
        #expect(run.code == 73)
        #expect(last.files == lastBefore)
        #expect(run.lines.first?.contains("batch/out/dune-small.fake") == true)
    }

    /// A dry run prints the plan as one object and writes nothing; it still refuses a collision.
    @Test func dryRunPrintsThePlanAndWritesNothing() throws {
        let io = try Self.world()
        let before = io.files
        let run = Self.run("batch/resize.jobs.json", io: io, dryRun: true)
        #expect(run.code == 0)
        #expect(run.lines.count == 1)
        #expect(run.report?["ok"] == .bool(true))
        #expect(Self.outputs.allSatisfy { run.lines.first?.contains($0) == true })
        #expect(io.files == before)
        let taken = try Self.world(["batch/out/city-small.fake": Data()])
        #expect(Self.run("batch/resize.jobs.json", io: taken, dryRun: true).code == 73)
    }

    // MARK: Quality

    /// 100 fake inputs × 3 steps; the packet's budget is 2 s on Linux CI (reported, not failed on here).
    @Test func hundredInputsWithinBudget() throws {
        var extra: [String: Data] = [:]
        for n in 1...100 { extra["batch/input/n\(n).fake"] = try Self.fixture("input/beach.fake") }
        let io = try Self.world(extra)
        let clock = ContinuousClock()
        let start = clock.now
        let run = Self.run("batch/resize.jobs.json", io: io)
        print("BatchTests.hundredInputsWithinBudget: 103 inputs in \(clock.now - start) (budget 2 s)")
        #expect(run.code == 0)
        #expect(run.report?["written"] == .number(103))
    }

    /// 1,000 seeded mutations of the script, each one invalid, exit 64 or 65; none crashes or writes.
    @Test func fuzzedScriptsNeverCrash() throws {
        let base = try Self.fixture("resize.jobs.json")
        var seed: UInt64 = 0x5EED_CAFE
        func next(_ bound: Int) -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((seed >> 33) % UInt64(max(bound, 1)))
        }
        for round in 0..<1000 {
            let script: Data
            switch round % 5 {
            case 0: script = base.prefix(next(base.count - 2) + 1)
            case 1: script = try Self.variant { $0["version"] = .number(Double(next(1000) + 2)) }
            case 2: script = try Self.variant { $0[["version", "app", "inputs", "steps"][next(4)]] = nil }
            case 3: script = try Self.variant { $0["steps"] = [.string("x"), .number(1), .object([:])][next(3)] }
            default: script = try Self.variant { $0["steps"] = .array([.object(["id": .string("rect.\(next(1 << 20))"), "params": .null])]) }
            }
            let io = try Self.world(["batch/fuzz.jobs.json": script])
            let before = io.files
            let code = Self.run("batch/fuzz.jobs.json", io: io).code
            #expect(code == 64 || code == 65, "round \(round)")
            #expect(io.files == before, "round \(round)")
        }
    }
}

fileprivate extension JSONValue {
    subscript(key: String) -> JSONValue? { if case .object(let object) = self { object[key] } else { nil } }
    subscript(index: Int) -> JSONValue? {
        guard case .array(let array) = self, array.indices.contains(index) else { return nil }
        return array[index]
    }
    var items: [JSONValue]? { if case .array(let array) = self { array } else { nil } }
    var count: Int? { items?.count }
    var text: String? { if case .string(let text) = self { text } else { nil } }
}
