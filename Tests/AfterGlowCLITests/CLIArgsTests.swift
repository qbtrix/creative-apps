// CLIArgsTests.swift: LJ1 and the CL-args checks (afterglow-cli CL-3, checks
// first; CL-4 turns them on). Every single-shot form parses strictly, an
// unknown flag, app or command is 64 and names it, every run prints exactly
// one JSON object on stdout (keys sorted) and one human line on stderr only
// when `ok` is false, each error maps to its sysexits code, and the golden
// outputs in Golden/ match. Runs in process on FakeIO over the fake app.
// The runs that edit a document go through the catalog's run (command-catalog
// CC-7).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AfterGlowCLICore
import Testing

struct CLIArgsTests {
    /// The apps the router runs over in these tests: the five and the fake, which only tests register.
    static let apps = Apps.all + [Apps.fake]
    /// The fake fixture's bytes, `a.fake` in every run: "Rect 1" free, "Rect 2" locked, nothing selected once opened.
    static let fixture = (try? FakeCanvasDocument.fixture.save()) ?? Data()
    static let rect = #"{"x":1,"y":2,"w":3,"h":4}"#
    static let move = #"{"dx":1,"dy":0}"#

    /// One run: its exit code and the FakeIO it ran on.
    struct Run {
        let code: Int32; let io: FakeIO
        /// The one stdout line read back as a JSON object, nil unless exactly one object was printed.
        var reply: [String: JSONValue]? {
            guard io.stdout.count == 1, let line = io.stdout.first,
                  case .object(let fields)? = try? JSONValue(json: Data(line.utf8)) else { return nil }
            return fields
        }
        var ok: Bool? { if case .bool(let flag)? = reply?["ok"] { flag } else { nil } }
        var error: [String: JSONValue]? { if case .object(let body)? = reply?["error"] { body } else { nil } }
        var kind: String? { if case .string(let text)? = error?["kind"] { text } else { nil } }
        var message: String { if case .string(let text)? = error?["message"] { text } else { "" } }
    }

    /// Runs `afterglow <arguments>` on a FakeIO holding `files`.
    /// CL-4 routes this over `apps` (the router takes the registry, so the fake is known only here).
    static func afterglow(_ arguments: [String], files: [String: Data] = ["a.fake": fixture]) -> Run {
        let io = FakeIO(files: files)
        let code = CLI.run(arguments, apps: apps, io: io)
        return Run(code: code, io: io)
    }

    /// The run failed with `code` and `kind`, printed one object and one stderr line, both naming `naming`.
    static func expectFailure(_ run: Run, _ code: Int32, _ kind: String, naming: String,
                              sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(run.code == code, sourceLocation: sourceLocation)
        #expect(run.ok == false, "stdout: \(run.io.stdout)", sourceLocation: sourceLocation)
        #expect(run.kind == kind, sourceLocation: sourceLocation)
        #expect(run.message.contains(naming), "\(run.message) does not name \(naming)", sourceLocation: sourceLocation)
        #expect(run.io.stderr.count == 1, sourceLocation: sourceLocation)
        #expect(run.io.stderr.first?.contains(naming) == true, sourceLocation: sourceLocation)
    }

    /// Every single-shot form that succeeds on the fixture, with the reply key that carries its answer.
    static let forms: [([String], String)] = [
        (["--version"], "version"), (["--help"], "usage"), (["list-apps"], "apps"),
        (["fake", "list-commands"], "commands"), (["fake", "describe", "rect.add"], "command"),
        (["fake", "open", "a.fake"], "summary"), (["fake", "new", "--out", "c.fake"], "output"),
        (["fake", "rect.add", "--in", "a.fake", "--out", "b.fake", "--json", rect], "undoStep"),
        (["fake", "rect.add", "--in", "a.fake", "--in-place", "--json", rect], "undoStep"),
        (["fake", "export", "a.fake", "--format", "json", "--out", "a.json"], "outputs"),
    ]

    static func runsCommand(_ arguments: [String]) -> Bool { arguments.count > 1 && arguments[1] == "rect.add" }

    @Test(arguments: forms.filter { !runsCommand($0.0) })
    func everyFormAnswersWithOneObject(arguments: [String], key: String) {
        let run = Self.afterglow(arguments)
        #expect(run.code == 0, "\(arguments): \(run.io.stdout)")
        #expect(run.ok == true)
        #expect(run.reply?[key] != nil, "\(arguments) has no \(key)")
        #expect(run.io.stderr.isEmpty)
    }

    @Test(arguments: forms.filter { runsCommand($0.0) })
    func everyCommandFormAnswersWithOneObject(arguments: [String], key: String) {
        everyFormAnswersWithOneObject(arguments: arguments, key: key)
    }

    /// The exit-code table: (arguments, code, error kind, what the message names).
    static let table: [([String], Int32, String, String)] = [
        ([], 64, "usage", "afterglow"),
        (["paint", "list-commands"], 64, "usage", "unknown app paint"),
        (["fake", "describe"], 64, "usage", "missing"),
        (["fake", "describe", "rect.paint"], 64, "usage", "unknown command rect.paint"),
        (["fake", "rect.paint", "--in", "a.fake", "--out", "b.fake"], 64, "usage", "unknown command rect.paint"),
        (["fake", "rect.add", "--in", "a.fake", "--json", rect], 64, "usage", "--in-place"),
        (["fake", "rect.add", "--in", "a.fake", "--out", "b.fake", "--in-place", "--json", rect], 64, "usage", "--in-place"),
        (["fake", "rect.add", "--in", "a.fake", "--out"], 64, "usage", "--out"),
        (["fake", "rect.add", "--in", "a.fake", "--out", "b.fake", "--out", "c.fake", "--json", rect], 64, "usage", "--out"),
        (["fake", "export", "a.fake", "--format", "gif", "--out", "a.gif"], 64, "usage", "gif"),
        (["run"], 64, "usage", "missing"),
        (["fake", "rect.add", "--in", "a.fake", "--out", "b.fake", "--json", "{x:1"], 65, "data", "--json"),
        (["fake", "rect.add", "--in", "a.fake", "--out", "b.fake", "--json", #"{"x":1}"#], 65, "data", "rect.add"),
        (["fake", "open", "bad.fake"], 65, "data", "bad.fake"),
        (["fake", "rect.move", "--in", "a.fake", "--out", "b.fake", "--json", move], 69, "unavailable", "Select a rectangle first."),
        (["fake", "rect.select", "--in", "a.fake", "--out", "b.fake", "--json", #"{"id":99}"#], 70, "failed", "There is no rect 99."),
        (["fake", "rect.add", "--in", "a.fake", "--out", "a.fake", "--json", rect], 73, "exists", "a.fake"),
        (["fake", "open", "missing.fake"], 74, "io", "missing.fake"),
        (["fake", "rect.add", "--in", "missing.fake", "--out", "b.fake", "--json", rect], 74, "io", "missing.fake"),
    ]
    static func fromCatalog(_ naming: String) -> Bool { ["rect.add", "There is no rect 99."].contains(naming) }

    @Test(arguments: table.filter { !fromCatalog($0.3) })
    func exitCodeTable(arguments: [String], code: Int32, kind: String, naming: String) {
        let run = Self.afterglow(arguments, files: ["a.fake": Self.fixture, "bad.fake": Data("not a canvas".utf8)])
        Self.expectFailure(run, code, kind, naming: naming)
    }

    @Test(arguments: table.filter { fromCatalog($0.3) })
    func catalogExitCodes(arguments: [String], code: Int32, kind: String, naming: String) {
        exitCodeTable(arguments: arguments, code: code, kind: kind, naming: naming)
    }

    @Test(arguments: forms.map(\.0) + [["fake", "rect.add", "--in", "a.fake", "--out", "b.fake"]])
    func unknownFlagIs64(arguments: [String]) {
        let run = Self.afterglow(arguments + ["--colour", "red"])
        Self.expectFailure(run, 64, "usage", naming: "unknown flag --colour")
        #expect(run.io.files == ["a.fake": Self.fixture], "a refused parse wrote a file")
    }

    @Test(arguments: [["--version", "--json"], ["list-apps", "--force"], ["run", "s.jobs.json", "--fast"]])
    func aFlagFromAnotherFormIs64(arguments: [String]) {
        let flag = arguments.last ?? ""
        Self.expectFailure(Self.afterglow(arguments), 64, "usage", naming: "unknown flag \(flag)")
    }

    @Test(arguments: ["list-commands", "open", "new", "describe", "rect.add"])
    func unknownAppIs64(form: String) {
        Self.expectFailure(Self.afterglow(["paint", form]), 64, "usage", naming: "unknown app paint")
        // A real app's name is never unknown, even before it adopts the catalog.
        #expect(Self.afterglow(["photo", "list-commands"]).code != 64)
    }

    @Test
    func unavailableIs69() {
        let run = Self.afterglow(["fake", "rect.move", "--in", "a.fake", "--out", "b.fake", "--json", Self.move])
        Self.expectFailure(run, 69, "unavailable", naming: "Select a rectangle first.")
        #expect(run.io.files["b.fake"] == nil)
    }

    /// A run that parses but refuses (65, 69, 70) writes nothing: neither the `--out` file nor `--in-place`.
    @Test(arguments: [
        ("rect.add", #"{"x":1}"#), ("rect.add", "{x:1"), ("rect.move", move), ("rect.select", #"{"id":99}"#),
    ])
    func refusedWritesNothing(command: String, json: String) {
        let out = Self.afterglow(["fake", command, "--in", "a.fake", "--out", "b.fake", "--json", json])
        #expect([65, 69, 70].contains(out.code))
        #expect(out.io.files == ["a.fake": Self.fixture])
        let inPlace = Self.afterglow(["fake", command, "--in", "a.fake", "--in-place", "--json", json])
        #expect(inPlace.code == out.code)
        #expect(inPlace.io.files == ["a.fake": Self.fixture])
    }

    /// Every run, ok or not, prints exactly one JSON object with sorted keys; stderr has a line only when it failed.
    @Test(arguments: forms.map(\.0) + table.map(\.0))
    func oneJSONObjectPerRun(arguments: [String]) throws {
        let run = Self.afterglow(arguments, files: ["a.fake": Self.fixture, "bad.fake": Data("not a canvas".utf8)])
        let line = try #require(run.io.stdout.count == 1 ? run.io.stdout.first : nil, "stdout: \(run.io.stdout)")
        guard let ok = run.ok else { Issue.record("no ok in \(line)"); return }
        #expect(ok == (run.code == 0))
        #expect(run.io.stderr.count == (ok ? 0 : 1))
        #expect(line == (try Self.sorted(line)), "keys are not sorted: \(line)")
    }

    /// The golden forms by file name in Golden/.
    static let golden: [(String, [String])] = [
        ("list-commands", ["fake", "list-commands"]),
        ("describe", ["fake", "describe", "rect.add"]),
        ("run-refused", ["fake", "rect.move", "--in", "a.fake", "--out", "b.fake", "--json", move]),
    ]

    @Test
    func goldenRunOK() throws {
        try goldenOutputs(name: "run-ok", arguments: ["fake", "rect.add", "--in", "a.fake", "--out", "b.fake", "--json", Self.rect])
    }

    @Test(arguments: golden)
    func goldenOutputs(name: String, arguments: [String]) throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Golden").appendingPathComponent("\(name).json")
        let want = try JSONValue(json: try Data(contentsOf: file))
        let run = Self.afterglow(arguments)
        #expect(run.io.stdout.count == 1)
        #expect(try JSONValue(json: Data((run.io.stdout.first ?? "").utf8)) == want, "\(name) differs: \(run.io.stdout)")
    }

    /// LJ1: list the fake's commands, describe one, add a rect to a copy, refuse an unknown flag and an overwrite.
    @Test
    func lj1FakeSession() throws {
        let list = Self.afterglow(["fake", "list-commands"])
        guard case .array(let commands)? = list.reply?["commands"] else { Issue.record("no commands: \(list.io.stdout)"); return }
        let ids = commands.compactMap { entry -> String? in
            if case .object(let fields) = entry, case .string(let id)? = fields["id"] { id } else { nil }
        }
        #expect(ids == FakeCanvasDocument.catalog.ids)
        #expect(Set(["rect.add", "rect.move", "rect.remove", "rect.select", "rect.list", "doc.export-json"]).isSubset(of: ids))

        let describe = Self.afterglow(["fake", "describe", "rect.add"])
        guard case .object(let command)? = describe.reply?["command"] else { Issue.record("no command: \(describe.io.stdout)"); return }
        #expect(command["params"] == FakeCanvasDocument.catalog.describe("rect.add")?.params)

        let add = Self.afterglow(["fake", "rect.add", "--in", "a.fake", "--out", "b.fake", "--json", Self.rect])
        #expect(add.code == 0)
        #expect(add.reply?["undoStep"] == .string("Add Rectangle"))
        let written = try FakeCanvasDocument.open(try #require(add.io.files["b.fake"]), name: "b.fake")
        #expect(written.rects.count == FakeCanvasDocument.fixture.rects.count + 1)
        #expect(written.rects.last == FakeRect(id: 3, name: "Rect 3", x: 1, y: 2, w: 3, h: 4))
        #expect(add.io.files["a.fake"] == Self.fixture, "the input changed without --in-place")

        let colour = Self.afterglow(["fake", "rect.add", "--in", "a.fake", "--out", "b.fake", "--colour", "red"])
        Self.expectFailure(colour, 64, "usage", naming: "unknown flag --colour")

        let files = add.io.files
        let again = Self.afterglow(["fake", "rect.add", "--in", "b.fake", "--out", "b.fake", "--json", Self.rect], files: files)
        Self.expectFailure(again, 73, "exists", naming: "b.fake")
        #expect(again.io.files == files)
    }

    /// `line` re-encoded with sorted keys, as the CLI prints it.
    static func sorted(_ line: String) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(try JSONValue(json: Data(line.utf8))), as: UTF8.self)
    }
}
