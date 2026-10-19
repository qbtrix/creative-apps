// CLIBinaryTests.swift: LJ4 (afterglow-cli CL-10). The built `afterglow`
// binary, spawned as a process in a temp directory, runs LJ1's fake session
// and LJ2's batch script on the real disk and agrees with CLI.run in process
// on FakeIO: the same exit codes, the same stdout and stderr lines. The binary
// is found beside the test bundle (`.build/<config>/afterglow`); when it isn't
// there each test is skipped by name. Process needs the whole Foundation.
import AfterGlowCLICore
import Foundation
import Testing

struct CLIBinaryTests {
    /// The `afterglow` executable in the build folder that holds this test bundle, if any.
    static let binary: URL? = {
        let starts = [URL(fileURLWithPath: CommandLine.arguments.first ?? ""), Bundle.main.bundleURL]
            + Bundle.allBundles.map(\.bundleURL)
        for start in starts {
            var folder = start.deletingLastPathComponent()
            for _ in 0..<5 {
                let candidate = folder.appendingPathComponent("afterglow")
                if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
                folder = folder.deletingLastPathComponent()
            }
        }
        return nil
    }()

    /// Skips a test by name when the binary isn't built beside the test bundle.
    static let built = binary != nil

    static let fixture = (try? FakeCanvasDocument.fixture.save()) ?? Data()
    static let rect = #"{"x":1,"y":2,"w":3,"h":4}"#
    static let batch = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures").appendingPathComponent("Batch")
    static let batchNames = ["resize.jobs.json", "atomic.jobs.json", "input/beach.fake", "input/city.fake",
                             "input/dune.fake", "mixed/a.fake", "mixed/b.fake", "mixed/c.fake"]

    /// One run's exit code and the lines it printed.
    struct Run: Equatable { let code: Int32; let out: [String]; let err: [String] }

    /// A fresh temp directory holding `files` by relative path, and its path.
    static func disk(_ files: [String: Data]) throws -> String {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("afterglow-bin-\(UUID().uuidString)")
        for (name, data) in files {
            let url = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }
        return root.path
    }

    /// Spawns the binary with `arguments` in `folder` and waits for it.
    static func spawn(_ arguments: [String], in folder: String) throws -> Run {
        let process = Process(), out = Pipe(), err = Pipe()
        process.executableURL = try #require(binary)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: folder)
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let stdout = out.fileHandleForReading.readDataToEndOfFile(), stderr = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let lines = { (data: Data) in String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init) }
        return Run(code: process.terminationStatus, out: lines(stdout), err: lines(stderr))
    }

    /// The same invocation in process, on a FakeIO holding `files`.
    static func inProcess(_ arguments: [String], files: [String: Data]) -> (Run, FakeIO) {
        let io = FakeIO(files: files)
        let code = CLI.run(arguments, io: io)
        return (Run(code: code, out: io.stdout, err: io.stderr), io)
    }

    static func file(_ folder: String, _ name: String) -> Data? { FileManager.default.contents(atPath: folder + "/" + name) }

    /// LJ4, LJ1's step: list, describe, add a rect to a copy on disk, refuse an unknown flag and an overwrite.
    @Test(.enabled(if: built, "afterglow not found beside the test bundle")) func lj4FakeSession() throws {
        let files = ["a.fake": Self.fixture]
        let folder = try Self.disk(files)
        let world = FakeIO(files: files)
        let forms: [([String], Int32)] = [
            (["--version"], 0),
            (["fake", "list-commands"], 0),
            (["fake", "describe", "rect.add"], 0),
            (["fake", "rect.add", "--in", "a.fake", "--out", "b.fake", "--json", Self.rect], 0),
            (["fake", "rect.add", "--in", "a.fake", "--out", "b.fake", "--json", Self.rect], 73),
            (["fake", "rect.add", "--in", "a.fake", "--out", "c.fake", "--colour", "red"], 64),
            (["fake", "open", "missing.fake"], 74),
        ]
        for (arguments, code) in forms {
            let binary = try Self.spawn(arguments, in: folder)
            let wanted = CLI.run(arguments, io: world)
            #expect(binary.code == code, "\(arguments): \(binary)")
            #expect(binary.code == wanted, "\(arguments) disagrees with CLI.run")
        }
        #expect(Self.file(folder, "b.fake") == world.files["b.fake"], "b.fake on disk is not what CLI.run writes")
        let written = try FakeCanvasDocument.open(try #require(Self.file(folder, "b.fake")), name: "b.fake")
        #expect(written.rects.count == FakeCanvasDocument.fixture.rects.count + 1)
        #expect(Self.file(folder, "a.fake") == Self.fixture, "the input changed")
        #expect(Self.file(folder, "c.fake") == nil)
    }

    /// Every line the binary prints matches CLI.run's, success and failure alike.
    @Test(.enabled(if: built, "afterglow not found beside the test bundle"),
          arguments: [["fake", "list-commands"], ["fake", "rect.add", "--in", "a.fake", "--out", "b.fake", "--json", rect],
                      ["fake", "rect.add", "--in", "a.fake", "--out", "a.fake", "--json", rect], ["paint", "list-commands"]])
    func binaryAgreesWithCLIRun(arguments: [String]) throws {
        let files = ["a.fake": Self.fixture]
        let binary = try Self.spawn(arguments, in: try Self.disk(files))
        #expect(binary == Self.inProcess(arguments, files: files).0)
    }

    /// LJ4, LJ2's script: three outputs and the golden report, a second run refuses, atomic keeps a bad input out.
    @Test(.enabled(if: built, "afterglow not found beside the test bundle")) func lj4Batch() throws {
        var files: [String: Data] = [:]
        for name in Self.batchNames { files["batch/" + name] = try Data(contentsOf: Self.batch.appendingPathComponent(name)) }
        let folder = try Self.disk(files)

        let first = try Self.spawn(["run", "batch/resize.jobs.json"], in: folder)
        #expect(first.code == 0, "\(first)")
        let report = try JSONValue(json: Data((first.out.first ?? "").utf8))
        #expect(first.out.count == 1)
        #expect(report == (try JSONValue(json: Data(contentsOf: Self.batch.appendingPathComponent("resize.report.json")))))
        for stem in ["beach", "city", "dune"] { #expect(Self.file(folder, "batch/out/\(stem)-small.fake") != nil) }
        #expect(first == Self.inProcess(["run", "batch/resize.jobs.json"], files: files).0)

        let again = try Self.spawn(["run", "batch/resize.jobs.json"], in: folder)
        #expect(again.code == 73, "\(again)")

        let atomic = try Self.spawn(["run", "batch/atomic.jobs.json"], in: folder)
        #expect(atomic.code == 70, "\(atomic)")
        #expect(Self.file(folder, "batch/out/b-small.fake") == nil)
        #expect(Self.file(folder, "batch/out/a-small.fake") != nil)
    }

    /// Start-up budget: `afterglow --version` ≤ 150 ms wall on Linux CI (reported, not failed).
    @Test(.enabled(if: built, "afterglow not found beside the test bundle")) func versionIsFast() throws {
        let start = Date()
        let run = try Self.spawn(["--version"], in: FileManager.default.temporaryDirectory.path)
        let elapsed = Date().timeIntervalSince(start)
        #expect(run.code == 0)
        print("afterglow --version took \(Int(elapsed * 1000)) ms (budget 150 ms)")
    }
}
