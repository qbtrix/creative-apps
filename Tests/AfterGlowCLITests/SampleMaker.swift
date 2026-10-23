// SampleMaker.swift (sample-files SS-2, docs/blueprints/suite/features/sample-files.md):
// the make step for the bundled samples. It lives here, not in scripts/, because
// scripts/ is a protected path the fast lane refuses. A sample is made by one
// make file, `Bundle/Samples/make/<sample file name>.jobs.json` (Cards.design is
// made by Cards.design.jobs.json): the CLI's own script format (Script.swift) plus
// an optional `new` object, the options its app's headless `new` gets. The maker
// seeds `seed.<native ext>` with that `new` next to a copy of the script, in an
// in-memory FakeIO, runs it through `afterglow run` (CLI.run, ScriptRunner) and
// takes the one file the run writes as the sample. So a make file's `inputs` is
// `["seed.<ext>"]` and its run writes exactly one output.
//
// Where a sample goes: `Bundle/Samples/<name>` plus its copy in
// `UITests/Fixtures/suite/<name>`. A make file under `make/fixtures-only/` makes
// a journey fixture that the tour doesn't ship (Logo.design, Title.flare,
// Logo.flare), so it goes to `UITests/Fixtures/suite/<name>` only.
//
// check (SampleMakerTests, in scripts/ci) rebuilds every sample and reports each
// committed copy that is missing or differs byte for byte, and a sample whose
// two builds differ. write (MAKE_SAMPLES=1) writes them all.
import AfterGlowCLICore
import Foundation
import SuiteKernel

enum SampleMaker {
    static let makeFolder = "Bundle/Samples/make", fixturesOnlyFolder = "fixtures-only"
    static let samplesFolder = "Bundle/Samples", fixturesFolder = "UITests/Fixtures/suite"
    static let suffix = ".jobs.json"
    /// How to refresh the samples, said by every check problem.
    static let fix = "run MAKE_SAMPLES=1 swift test --filter SampleMakerTests"

    /// Why a make file made no sample.
    struct Failure: Error, CustomStringConvertible { let description: String }

    /// One make file: the sample it makes, its repo path, and whether the sample is a journey fixture only.
    struct Recipe: Hashable {
        let name: String, path: String, fixtureOnly: Bool
        /// The repo paths the sample is committed at: Bundle/Samples/ (unless fixture-only), then the fixture copy.
        var bundlePath: String? { fixtureOnly ? nil : SampleMaker.samplesFolder + "/" + name }
        var fixturePath: String { SampleMaker.fixturesFolder + "/" + name }
    }

    /// Every make file under `root`, sorted by path; none when the folder is missing.
    static func recipes(root: URL) -> [Recipe] {
        func list(_ folder: String, fixtureOnly: Bool) -> [Recipe] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent(folder).path)) ?? []
            return names.filter { $0.hasSuffix(suffix) && $0.count > suffix.count }.sorted().map {
                Recipe(name: String($0.dropLast(suffix.count)), path: folder + "/" + $0, fixtureOnly: fixtureOnly)
            }
        }
        return list(makeFolder, fixtureOnly: false) + list(makeFolder + "/" + fixturesOnlyFolder, fixtureOnly: true)
    }

    /// The sample `recipe` makes: its script run headless over a `new` seed, in memory.
    static func build(_ recipe: Recipe, root: URL) throws -> Data {
        let script = try Data(contentsOf: root.appendingPathComponent(recipe.path))
        let parsed: Script
        do { parsed = try Script.parse(script, path: recipe.path) } catch { throw Failure(description: "\(recipe.path): \(error.message)") }
        guard let app = Apps.named(parsed.app, in: CLI.registry), let ext = app.openExtensions.first else {
            throw Failure(description: "\(recipe.path): unknown app \(parsed.app)")
        }
        var options = JSONValue.object([:])
        if case .object(let fields)? = try? JSONValue(json: script), let new = fields["new"] { options = new }
        let scriptPath = "work/" + recipe.name + suffix, seedPath = "work/seed." + ext
        let io = FakeIO(files: [scriptPath: script, seedPath: try app.session(new: options).save()])
        let before = Set(io.files.keys)
        let code = CLI.run(["run", scriptPath], io: io)
        guard code == CLI.Exit.ok else {
            throw Failure(description: "\(recipe.path): afterglow run exited \(code): \(io.stdout.joined(separator: " "))")
        }
        let written = io.files.filter { !before.contains($0.key) }
        guard written.count == 1, let output = written.first else {
            throw Failure(description: "\(recipe.path) wrote \(written.count) files; a make file writes one")
        }
        return output.value
    }

    /// What is wrong with the committed samples under `root`: one line per problem, none when all match.
    static func check(root: URL) -> [String] {
        recipes(root: root).flatMap { recipe -> [String] in
            let made: Data, again: Data
            do { (made, again) = (try build(recipe, root: root), try build(recipe, root: root)) } catch { return ["\(error)"] }
            if made != again { return ["\(recipe.path) makes different bytes on each run; keep it deterministic"] }
            var problems: [String] = []
            for (path, required) in [(recipe.bundlePath, true), (recipe.fixturePath, recipe.fixtureOnly)] {
                guard let path else { continue }
                let committed = try? Data(contentsOf: root.appendingPathComponent(path))
                if committed == nil, !required { continue }
                if committed == nil { problems.append("\(path) is missing; \(fix)") }
                else if committed != made { problems.append("\(path) differs from what \(recipe.path) makes; \(fix)") }
            }
            return problems
        }
    }

    /// Makes every sample under `root` and writes it to Bundle/Samples/ (unless fixture-only) and
    /// UITests/Fixtures/suite/. Returns the repo paths written, in order.
    @discardableResult
    static func write(root: URL) throws -> [String] {
        var written: [String] = []
        for recipe in recipes(root: root) {
            let made = try build(recipe, root: root)
            for path in [recipe.bundlePath, recipe.fixturePath].compactMap({ $0 }) {
                let url = root.appendingPathComponent(path)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try made.write(to: url, options: .atomic)
                written.append(path)
            }
        }
        return written
    }
}
