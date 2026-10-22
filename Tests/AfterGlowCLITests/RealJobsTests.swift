// RealJobsTests.swift: LJ3 (afterglow-cli CL-8 writes it, CL-9 turns it on
// and adds the digest, JSON, missing-output and pixel checks; slice CL-jobs). A real job is a folder `Tests/RealJobs/<app>/<job>/` with
// one `*.jobs.json` (the script format, plus `expect`, `platforms` and
// `why`) and its inputs. Each job's folder is copied into a fresh FakeIO,
// its own temp dir, under its repo path, so its outputs never touch the
// source tree, and `RealJobs.check` runs it there. Every job must pass, or
// be skipped on this platform with its reason; a skip is reported as one,
// never as a pass. The broken fixture (Fixtures/RealJobsBroken/, a copy of
// fake/add-rect whose sha256 differs from the right one in its last digit
// only) must fail, naming the job and the output path. Files are read by
// path from #filePath.
//
// The report `check` prints, one JSON object on stdout: `"ok"` is true when
// every expectation held; a failing job prints `"ok": false` and exits
// non-zero; a skipped job prints `"skipped": "<reason>"`.
import AfterGlowCLICore
import Foundation
import Testing

/// Finds real jobs on disk and loads one into an in-memory file system.
enum RealJobsHarness {
    /// The repo's root: three folders up from this file.
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    /// The real jobs, and the broken fixture tree laid out the same way.
    static let jobsTree = "Tests/RealJobs", brokenTree = "Tests/AfterGlowCLITests/Fixtures/RealJobsBroken"
    /// The apps a job may name: the CLI's registry, the five, the suite and the fake.
    static let apps = CLI.registry

    /// Every `<app>/<job>` folder under `tree` that holds a `*.jobs.json`, as repo paths, sorted.
    static func jobs(in tree: String) -> [String] {
        let fm = FileManager.default
        let base = root.appendingPathComponent(tree)
        let apps = ((try? fm.contentsOfDirectory(atPath: base.path)) ?? []).sorted()
        return apps.flatMap { app -> [String] in
            let names = ((try? fm.contentsOfDirectory(atPath: base.appendingPathComponent(app).path)) ?? []).sorted()
            return names.map { "\(tree)/\(app)/\($0)" }.filter { !scripts(in: $0).isEmpty }
        }
    }

    /// The `*.jobs.json` files directly in the job folder `job`.
    static func scripts(in job: String) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent(job).path)) ?? []
        return names.filter { $0.hasSuffix(".jobs.json") }.sorted()
    }

    /// A fresh FakeIO holding every file of the job folder `job` under its repo path, `out/` left behind.
    static func mount(_ job: String) -> FakeIO {
        let base = root.appendingPathComponent(job)
        guard let walker = FileManager.default.enumerator(atPath: base.path) else { return FakeIO() }
        var files: [String: Data] = [:]
        while let path = walker.nextObject() as? String {
            // A folder doesn't read as data, so only files land.
            guard !path.hasPrefix("out/"), let data = try? Data(contentsOf: base.appendingPathComponent(path)) else { continue }
            files["\(job)/\(path)"] = data
        }
        return FakeIO(files: files)
    }

    /// The one JSON object `check` printed, nil when it printed anything else.
    static func report(_ io: FakeIO) -> [String: JSONValue]? {
        guard io.stdout.count == 1, let line = io.stdout.first,
              case .object(let fields)? = try? JSONValue(json: Data(line.utf8)) else { return nil }
        return fields
    }

    /// Everything `check` printed, stdout then stderr, for messages that must name something.
    static func printed(_ io: FakeIO) -> String { (io.stdout + io.stderr).joined(separator: "\n") }
}

/// The real-jobs tree is laid out as the harness reads it. Runs now: it reads files only.
struct RealJobsLayoutTests {
    @Test func theTreesHoldTheFakeJobsAndTheBrokenFixture() {
        #expect(RealJobsHarness.jobs(in: RealJobsHarness.jobsTree).filter { $0.hasPrefix("Tests/RealJobs/fake/") }
            == ["Tests/RealJobs/fake/add-rect", "Tests/RealJobs/fake/file-flow", "Tests/RealJobs/fake/gradient-fill",
               "Tests/RealJobs/fake/history-jump", "Tests/RealJobs/fake/move-each",
               "Tests/RealJobs/fake/turn-flip"])
        #expect(RealJobsHarness.jobs(in: RealJobsHarness.brokenTree)
            == ["Tests/AfterGlowCLITests/Fixtures/RealJobsBroken/fake/wrong-sha"])
    }

    @Test func everyJobHasOneVersionedScriptForAKnownAppWithExpectationsAndInputs() throws {
        let jobs = RealJobsHarness.jobs(in: RealJobsHarness.jobsTree) + RealJobsHarness.jobs(in: RealJobsHarness.brokenTree)
        for job in jobs {
            let scripts = RealJobsHarness.scripts(in: job)
            #expect(scripts.count == 1, "\(job) holds \(scripts.count) *.jobs.json files, not one")
            let io = RealJobsHarness.mount(job)
            let script = try JSONValue(json: try io.read("\(job)/\(scripts.first ?? "")"))
            guard case .object(let fields) = script else { Issue.record("\(job): the script is not an object"); continue }
            #expect(fields["version"] == .number(1), "\(job)")
            let app = if case .string(let name)? = fields["app"] { name } else { "" }
            #expect(Apps.named(app, in: RealJobsHarness.apps) != nil, "\(job) names no known app")
            #expect(job.split(separator: "/").dropLast().last.map(String.init) == app, "\(job) sits under another app's folder")
            if case .object(let expect)? = fields["expect"] { #expect(!expect.isEmpty, "\(job) expects nothing") }
            else { Issue.record("\(job) has no expect block") }
            #expect(io.files.keys.contains { $0.hasPrefix("\(job)/input/") }, "\(job) has no inputs")
        }
    }
}

/// LJ3: every real job passes or is skipped with its reason, and a wrong expectation fails.
struct RealJobsTests {
    @Test
    func everyRealJobPassesOrIsSkippedWithItsReason() throws {
        let jobs = RealJobsHarness.jobs(in: RealJobsHarness.jobsTree)
        #expect(!jobs.isEmpty)
        for job in jobs {
            let io = RealJobsHarness.mount(job)
            let code = RealJobs.check(job, apps: RealJobsHarness.apps, io: io)
            let report = try #require(RealJobsHarness.report(io), "\(job) printed \(io.stdout)")
            #expect(code == 0, "\(job) exited \(code): \(RealJobsHarness.printed(io))")
            if case .string(let why)? = report["skipped"] {
                #expect(!job.hasPrefix("Tests/RealJobs/fake/"), "\(job) runs everywhere but was skipped: \(why)")
                // A job waiting on a slice names it in `pending` and its why (AllAppsCatalogTests checks the
                // gap); `platforms: []` then skips it on both platforms, so either prefix is fine for it.
                let pending = try AllAppsCatalogTests.pending(job).map(why.contains) == true
                #expect(why.hasPrefix("macOS-only: ") || why.contains("waits on image-codecs") || pending, "\(job) skipped as \(why)")
            } else {
                #expect(report["ok"] == .bool(true), "\(job): \(RealJobsHarness.printed(io))")
            }
        }
    }

    @Test
    func aWrongSha256FailsNamingTheJobAndTheOutputPath() throws {
        let job = "Tests/AfterGlowCLITests/Fixtures/RealJobsBroken/fake/wrong-sha"
        let io = RealJobsHarness.mount(job)
        let code = RealJobs.check(job, apps: RealJobsHarness.apps, io: io)
        let report = try #require(RealJobsHarness.report(io), "printed \(io.stdout)")
        #expect(code != 0)
        #expect(report["ok"] == .bool(false))
        #expect(report["skipped"] == nil)
        let printed = RealJobsHarness.printed(io)
        #expect(printed.contains("wrong-sha"), "the failure doesn't name the job: \(printed)")
        #expect(printed.contains("out/one-added.json"), "the failure doesn't name the output: \(printed)")
    }

    /// A job in memory: one fake input, one rect.add, and `extra` merged into the script.
    static func inlineJob(_ job: String, _ extra: String) -> FakeIO {
        let input = #"[{"h":60,"id":1,"locked":false,"name":"Rect 1","w":100,"x":10,"y":10}]"#
        let script = #"{"version": 1, "app": "fake", "inputs": ["input/*.fake"], "#
            + #""steps": [{"id": "rect.add", "params": {"x": 1, "y": 2, "w": 3, "h": 4}}], "atomic": true, "#
            + #""output": {"dir": "out", "name": "{stem}-added", "format": "json", "options": {}}, "# + extra + "}"
        return FakeIO(files: ["\(job)/input/one.fake": Data(input.utf8), "\(job)/\(job.split(separator: "/").last ?? "").jobs.json": Data(script.utf8)])
    }

    @Test
    func aMacOSOnlyJobIsSkippedOnLinuxWithItsWhyNeverPassed() throws {
        let job = "jobs/fake/mac-only"
        let io = Self.inlineJob(job, #""expect": {"out/one-added.json": {"sha256": "\#(String(repeating: "0", count: 64))"}}, "#
            + #""platforms": ["macos"], "why": "needs the Metal renderer""#)
        let code = RealJobs.check(job, apps: RealJobsHarness.apps, io: io)
        let report = try #require(RealJobsHarness.report(io), "printed \(io.stdout)")
        #if os(Linux)
        #expect(code == 0)
        #expect(report["skipped"] == .string("macOS-only: needs the Metal renderer"))
        #expect(!io.exists("\(job)/out/one-added.json"), "a skipped job ran")
        #else
        #expect(code != 0, "the wrong sha256 passed on macOS")
        #expect(report["skipped"] == nil)
        #endif
    }

    @Test
    func aPixelJobBeforeImageCodecsIsSkippedNeverPassed() throws {
        let job = "jobs/fake/pixels"
        let io = Self.inlineJob(job, #""expect": {"out/one-added.json": {"pixels": {"tolerance": 2, "reference": "expected/one.png"}}}"#)
        let code = RealJobs.check(job, apps: RealJobsHarness.apps, io: io)
        let report = try #require(RealJobsHarness.report(io), "printed \(io.stdout)")
        #expect(code == 0)
        guard case .string(let why)? = report["skipped"] else {
            Issue.record("a pixel expectation was not skipped: \(RealJobsHarness.printed(io))"); return
        }
        #expect(why.contains("waits on image-codecs"))
    }

    @Test func aWrongJSONOrAMissingOutputFailsNamingThePath() throws {
        for (name, expect) in [("json", #"{"out/one-added.json": {"json": []}}"#), ("missing", #"{"out/none.json": {"sha256": "00"}}"#)] {
            let job = "jobs/fake/\(name)"
            let io = Self.inlineJob(job, #""expect": "# + expect)
            let code = RealJobs.check(job, apps: RealJobsHarness.apps, io: io)
            let report = try #require(RealJobsHarness.report(io), "printed \(io.stdout)")
            #expect(code != 0, "\(name) passed")
            #expect(report["ok"] == .bool(false))
            #expect(RealJobsHarness.printed(io).contains(name == "json" ? "out/one-added.json" : "out/none.json"))
        }
    }
}

/// The digest and the pixel comparison the expectations rest on.
struct RealJobsCompareTests {
    @Test func sha256MatchesTheFIPSVectors() {
        #expect(RealJobs.sha256Hex(Data()) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(RealJobs.sha256Hex(Data("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let twoBlocks = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        #expect(RealJobs.sha256Hex(Data(twoBlocks.utf8)) == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }

    @Test func pixelsMatchWithinTheToleranceInclusiveAndOnlyAtTheSameSize() {
        #expect(RealJobs.pixelsMatch([10, 20, 30, 255], [12, 18, 30, 255], tolerance: 2))
        #expect(!RealJobs.pixelsMatch([10, 20, 30, 255], [13, 20, 30, 255], tolerance: 2))
        #expect(RealJobs.pixelsMatch([0, 0, 0, 0], [0, 0, 0, 0], tolerance: 0))
        #expect(!RealJobs.pixelsMatch([0, 0, 0, 0], [0, 0, 0], tolerance: 255))
    }
}
